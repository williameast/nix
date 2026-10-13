# Print the next timed calendar event as Waybar JSON.
# Reads Thunderbird's offline cache of its CalDAV (Google) calendars. Thunderbird
# holds an exclusive lock on cache.sqlite, so the db and its WAL are copied to a
# temp dir first. Recurring events are expanded with dateutil; all-day and
# cancelled events are skipped. Prints empty text (module hidden) if nothing is
# coming up in the next 7 days.
import json
import os
import shutil
import sqlite3
import sys
import tempfile
from datetime import datetime, timedelta, timezone
from zoneinfo import ZoneInfo

from dateutil.rrule import rruleset, rrulestr
from dateutil.tz import tzlocal

PROFILE = os.path.expanduser(sys.argv[1] if len(sys.argv) > 1 else "~/.thunderbird/default")
CACHE = os.path.join(PROFILE, "calendar-data", "cache.sqlite")
LOOKAHEAD = timedelta(days=7)
LOCAL = tzlocal()  # DST-aware, unlike a fixed offset taken from now()


def to_local(us, tz):
    """Thunderbird stores UTC microseconds; floating times are wall time as UTC."""
    dt = datetime.fromtimestamp(us / 1e6, timezone.utc)
    if tz == "floating":
        return dt.replace(tzinfo=LOCAL)
    return dt.astimezone(LOCAL)


def zone(tz):
    if tz == "floating":
        return LOCAL
    try:
        return ZoneInfo(tz)
    except Exception:
        return timezone.utc


def open_db():
    tmp = tempfile.mkdtemp(prefix="tb-agenda-")
    for suffix in ("", "-wal"):
        if os.path.exists(CACHE + suffix):
            shutil.copyfile(CACHE + suffix, os.path.join(tmp, "cache.sqlite" + suffix))
    return tmp, sqlite3.connect(os.path.join(tmp, "cache.sqlite"))


def occurrences(start, end, rules, tz, horizon):
    """Yield (start, end) of each occurrence; rules are RRULE/EXDATE/RDATE lines."""
    if not rules:
        yield start, end
        return
    length = end - start
    # Expand in the event's own zone so DST shifts keep the wall-clock time
    dtstart = start.astimezone(zone(tz))
    rs = rruleset()
    for line in rules:
        name, _, value = line.strip().partition(":")
        kind = name.split(";")[0]
        if kind == "RRULE":
            rs.rrule(rrulestr(value, dtstart=dtstart))
        elif kind in ("EXDATE", "RDATE"):
            params = dict(p.split("=", 1) for p in name.split(";")[1:] if "=" in p)
            for v in value.split(","):
                fmt = "%Y%m%dT%H%M%S" if "T" in v else "%Y%m%d"
                d = datetime.strptime(v.rstrip("Z"), fmt)
                d = d.replace(tzinfo=timezone.utc if v.endswith("Z")
                              else zone(params.get("TZID", tz)))
                (rs.exdate if kind == "EXDATE" else rs.rdate)(d)
    for s in rs:
        s = s.astimezone(LOCAL)
        if s > horizon:
            return
        yield s, s + length


def events(now):
    tmp, db = open_db()
    try:
        rules = {}
        for item, ical in db.execute("SELECT item_id, icalString FROM cal_recurrence"):
            rules.setdefault(item, []).extend(l for l in ical.splitlines() if l.strip())
        rows = db.execute(
            "SELECT id, title, event_start, event_end, event_start_tz, recurrence_id,"
            " recurrence_id_tz, ical_status FROM cal_events"
            " WHERE event_start IS NOT NULL").fetchall()
    finally:
        db.close()
        shutil.rmtree(tmp, ignore_errors=True)

    # Edited instances of a recurring event replace the generated occurrence
    overridden = {(r[0], to_local(r[5], r[6])) for r in rows if r[5] is not None}
    horizon = now + LOOKAHEAD
    for id_, title, s, e, tz, rid, _, status in rows:
        if tz == "floating" or (status or "").upper() == "CANCELLED":
            continue  # all-day or cancelled
        start, end = to_local(s, tz), to_local(e or s, tz)
        series = rules.get(id_) if rid is None else None
        for occ_start, occ_end in occurrences(start, end, series, tz, horizon):
            if rid is None and (id_, occ_start) in overridden:
                continue
            if occ_end >= now and occ_start <= horizon:
                yield occ_start, occ_end, title or "(no title)"


def main():
    now = datetime.now(LOCAL)
    try:
        found = sorted(events(now), key=lambda e: e[0])
    except (OSError, sqlite3.Error):
        found = []
    if not found:
        print(json.dumps({"text": "", "class": "none"}))
        return
    start, _, title = found[0]
    if len(title) > 32:
        title = title[:31] + "…"
    delta = start - now
    if delta <= timedelta(0):
        when, cls = "now", "now"
    elif delta < timedelta(hours=1):
        when, cls = f"in {int(delta.total_seconds() // 60) + 1}m", "soon"
    elif start.date() == now.date():
        when, cls = start.strftime("%H:%M"), "today"
    elif start.date() == (now + timedelta(days=1)).date():
        when, cls = start.strftime("tmrw %H:%M"), "later"
    else:
        when, cls = start.strftime("%a %H:%M"), "later"
    text = f"{when} · {title}"
    text = text.replace("&", "&amp;").replace("<", "&lt;").replace(">", "&gt;")
    print(json.dumps({"text": text, "class": cls}))


if __name__ == "__main__":
    main()
