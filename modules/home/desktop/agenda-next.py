# Print the next timed org event as Waybar JSON.
# Scans ~/org for active timestamps <YYYY-MM-DD Day HH:MM[-HH:MM] [+Nx]>
# (plain, SCHEDULED, or org-gcal), skipping DONE/CANCELLED headings and
# archives. Prints empty text (module hidden) if nothing in the next 7 days.
import json
import os
import re
import sys
from datetime import datetime, timedelta

ORG_DIR = os.path.expanduser(sys.argv[1] if len(sys.argv) > 1 else "~/org")
LOOKAHEAD = timedelta(days=7)
SKIP_DIRS = {"archive", ".git", ".stversions"}
DONE = {"DONE", "CANCELLED", "CANCELED", "KILL", "[X]"}

HEADING = re.compile(r"^(\*+)\s+(?:([A-Z]+)\s+)?(.*?)(?:\s+:[\w@#%:]+:)?\s*$")
STAMP = re.compile(
    r"<(\d{4})-(\d{2})-(\d{2})[^>\d]*(\d{1,2}):(\d{2})(?:-(\d{1,2}):(\d{2}))?"
    r"[^>]*?(?:\s(?:\+\+|\.\+|\+)(\d+)([hdwmy]))?[^>]*>"
)


def add_months(dt, n):
    m = dt.month - 1 + n
    y = dt.year + m // 12
    m = m % 12 + 1
    day = min(dt.day, [31, 29 if y % 4 == 0 else 28, 31, 30, 31, 30,
                       31, 31, 30, 31, 30, 31][m - 1])
    return dt.replace(year=y, month=m, day=day)


def advance(dt, n, unit):
    if unit == "h":
        return dt + timedelta(hours=n)
    if unit == "d":
        return dt + timedelta(days=n)
    if unit == "w":
        return dt + timedelta(weeks=n)
    if unit == "m":
        return add_months(dt, n)
    return add_months(dt, 12 * n)


def events(now):
    for root, dirs, files in os.walk(ORG_DIR):
        dirs[:] = [d for d in dirs if d not in SKIP_DIRS]
        for name in files:
            if not name.endswith(".org"):
                continue
            try:
                with open(os.path.join(root, name), encoding="utf-8",
                          errors="replace") as f:
                    lines = f.readlines()
            except OSError:
                continue
            title, done = None, False
            for line in lines:
                h = HEADING.match(line)
                if h:
                    title = h.group(3).strip()
                    done = (h.group(2) or "") in DONE
                    continue
                if title is None or done:
                    continue
                for m in STAMP.finditer(line):
                    y, mo, d, hh, mm, eh, em, rn, ru = m.groups()
                    start = datetime(int(y), int(mo), int(d), int(hh), int(mm))
                    length = timedelta(0)
                    if eh:
                        end = start.replace(hour=int(eh), minute=int(em))
                        length = max(end - start, timedelta(0))
                    if rn and int(rn) > 0:
                        while start + length < now:
                            start = advance(start, int(rn), ru)
                    if start + length >= now and start - now <= LOOKAHEAD:
                        yield start, length, title


def main():
    now = datetime.now()
    found = sorted(events(now), key=lambda e: e[0])
    if not found:
        print(json.dumps({"text": "", "class": "none"}))
        return
    start, length, title = found[0]
    title = re.sub(r"\[\[(?:[^]]*\]\[)?([^]]*)\]\]", r"\1", title)
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
