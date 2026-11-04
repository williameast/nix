# Music pipeline: watcher, status endpoint and alerts for seedbox → milo music
#
#   ultracc (seedbox)                         milo
#   rtorrent → red-staging.py (cron) ──Syncthing "music-staging"──→ /mnt/vault-new/staging/music
#              └ status.json ──────────Syncthing "seedbox-status"─→ ~/.local/state/seedbox-status
#
# The seedbox side (~/bin/red-staging.py on ultracc, not managed by Nix) copies
# finished RED torrents into music-staging, restarts rtorrent if it dies, and
# writes status.json every 2 minutes.
#
# This service on milo:
#   - sends "<album> is ready for import" to ntfy topic "music" once Syncthing
#     has every file of an album and nothing has been written for 2 minutes
#   - serves the combined status at http://localhost:${port}/status (JSON for
#     the homepage customapi widget) and /health (200 ok, 503 degraded)
#   - posts to ntfy topic "alerts" when a problem starts and when it clears
{ config, pkgs, lib, ... }:

let
  topology = import ../../home/syncthing-topology.nix { inherit lib; };

  port = 8095;
  ntfyBase = "http://localhost:2586";
  watchDir = "/mnt/vault-new/staging/music";
  seedboxStatus = "${config.services.syncthing.dataDir}/${topology.sharedFolders.seedbox-status.path}/status.json";
  syncthingUrl = "http://127.0.0.1:8384";
  syncthingConfig = "${config.services.syncthing.configDir}/config.xml";
  ultraccId = topology.machines.ultracc.deviceId;

  script = pkgs.writeScript "music-pipeline" ''
    #!${pkgs.python3}/bin/python3
    import json, os, re, threading, time, urllib.request
    from datetime import datetime, timezone
    from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer

    WATCH_DIR = "${watchDir}"
    SEEDBOX_STATUS = "${seedboxStatus}"
    STATE = os.path.join(os.environ["STATE_DIRECTORY"], "state.json")
    LEGACY_STATE = os.path.join(os.environ["STATE_DIRECTORY"], "notified.json")
    QUIET_SECS = 120
    POLL_SECS = 30
    IGNORE = {".stfolder", ".stversions", ".stignore"}

    # Problem thresholds
    STATUS_STALE = 15 * 60        # seedbox status.json older than this
    RTORRENT_DOWN = 10 * 60       # seedbox restarts it itself; alert if that didn't help
    ULTRACC_OFFLINE = 30 * 60     # Syncthing link to the seedbox
    QUOTA_FULL = 0.95

    STARTED = time.time()
    status = {"health": "starting"}
    lock = threading.Lock()


    def log(msg):
        print(msg, flush=True)


    def iso(ts):
        return datetime.fromtimestamp(ts, timezone.utc).isoformat() if ts else None


    def ntfy(topic, title, message, tags, priority="default"):
        req = urllib.request.Request(
            f"${ntfyBase}/{topic}", data=message.encode(),
            headers={"Title": title, "Tags": tags, "Priority": priority})
        try:
            urllib.request.urlopen(req, timeout=30).read()
        except Exception as e:
            log(f"ntfy failed: {e}")


    def syncthing(path):
        with open("${syncthingConfig}") as f:
            key = re.search(r"<apikey>(.*?)</apikey>", f.read()).group(1)
        req = urllib.request.Request("${syncthingUrl}" + path, headers={"X-API-Key": key})
        return json.load(urllib.request.urlopen(req, timeout=30))


    def load_state():
        try:
            with open(STATE) as f:
                return json.load(f)
        except FileNotFoundError:
            pass
        # Migrate from the old watcher (a plain list of announced albums), or
        # treat whatever is already in staging as announced on first start.
        try:
            with open(LEGACY_STATE) as f:
                names = json.load(f)
        except FileNotFoundError:
            names = albums()
        log(f"initialised with {len(names)} existing albums")
        return {"notified": {n: 0 for n in names}, "problems": {}, "since": {}}


    def save_state(state):
        with open(STATE + ".tmp", "w") as f:
            json.dump(state, f, indent=1, ensure_ascii=False)
        os.replace(STATE + ".tmp", STATE)


    def albums():
        return {n for n in os.listdir(WATCH_DIR)
                if n not in IGNORE and not n.startswith(".syncthing.")}


    def newest_mtime(path):
        newest = os.lstat(path).st_mtime
        for root, dirs, files in os.walk(path):
            for n in dirs + files:
                try:
                    newest = max(newest, os.lstat(os.path.join(root, n)).st_mtime)
                except FileNotFoundError:
                    pass
        return newest


    def check_albums(state, needed):
        """Announce albums that have fully arrived. Returns names still arriving."""
        notified = state["notified"]
        present = albums()
        for gone in set(notified) - present:
            # Imported/removed, so a re-delivery notifies again
            del notified[gone]
        arriving = []
        for album in sorted(present - set(notified)):
            busy = any(n == album or n.startswith(album + "/") for n in needed)
            if busy or time.time() - newest_mtime(os.path.join(WATCH_DIR, album)) < QUIET_SECS:
                arriving.append(album)
                continue
            ntfy("music", "Ready for import", f"{album} is ready for import", "musical_note")
            log(f"ready: {album}")
            notified[album] = int(time.time())
        return arriving


    def since(state, key, active):
        """Seconds a condition has been continuously true (0 if not active)."""
        if not active:
            state["since"].pop(key, None)
            return 0
        state["since"].setdefault(key, time.time())
        return time.time() - state["since"][key]


    def evaluate(state):
        now = time.time()
        problems = {}

        try:
            with open(SEEDBOX_STATUS) as f:
                seedbox = json.load(f)
        except (FileNotFoundError, ValueError):
            seedbox = {}
        age = now - seedbox.get("updated", 0)
        # Measured from service start at the earliest, so a restart (or the
        # folder's first sync) doesn't count as a silent seedbox
        if now - max(seedbox.get("updated", 0), STARTED) > STATUS_STALE:
            problems["stale"] = ("No status from the seedbox for "
                                 f"{age / 60:.0f} min (cron job or Syncthing broken)")
        if seedbox.get("rtorrent") == "down":
            down = now - (seedbox.get("rtorrent_down_since") or now)
            if down > RTORRENT_DOWN:
                problems["rtorrent"] = f"rtorrent down for {down / 60:.0f} min despite restarts"
        err = seedbox.get("error")
        if err and seedbox.get("rtorrent") == "up":
            problems["copy"] = f"Seedbox copy error: {err}"
        used, total = seedbox.get("quota_used"), seedbox.get("quota_total")
        if used and total and used / total > QUOTA_FULL:
            problems["quota"] = f"Seedbox quota {100 * used / total:.0f}% full"

        try:
            conns = syncthing("/rest/system/connections")["connections"]
            connected = conns.get("${ultraccId}", {}).get("connected", False)
            need = syncthing("/rest/db/need?folder=music-staging&perpage=100000")
            needed = {f["name"] for k in ("progress", "queued", "rest")
                      for f in need.get(k) or []}
            folder = syncthing("/rest/db/status?folder=music-staging")
            syncing_bytes = folder.get("needBytes", 0)
        except Exception as e:
            log(f"syncthing query failed: {e}")
            problems["syncthing"] = f"milo Syncthing API unreachable: {e}"
            connected, needed, syncing_bytes = None, set(), None
        offline = since(state, "ultracc_offline", connected is False)
        if offline > ULTRACC_OFFLINE:
            problems["ultracc"] = f"Seedbox not connected to milo's Syncthing for {offline / 60:.0f} min"

        # Without Syncthing we can't tell a half-synced album from a finished one
        arriving = check_albums(state, needed) if connected is not None else []
        notified = state["notified"]
        last = max(notified.items(), key=lambda kv: kv[1], default=(None, 0))
        if not last[1]:
            last = (None, 0)  # only albums carried over from before, no arrival time

        return problems, {
            "health": "degraded" if problems else "ok",
            "problems": "; ".join(problems.values()) or "none",
            "rtorrent": seedbox.get("rtorrent", "unknown"),
            "downloading": seedbox.get("downloading"),
            "seeding": seedbox.get("seeding"),
            "tracker_errors": seedbox.get("tracker_errors"),
            "seedbox_copied": seedbox.get("last_copied"),
            "seedbox_copied_at": iso(seedbox.get("last_copied_at")),
            "seedbox_free": (total - used) if used and total else None,
            "seedbox_status_age": int(age) if seedbox else None,
            "ultracc": {True: "connected", False: "disconnected"}.get(connected, "unknown"),
            "syncing_bytes": syncing_bytes,
            "arriving": len(arriving),
            "in_staging": len(notified),
            "last_arrival": last[0],
            "last_arrival_at": iso(last[1]),
            "updated": iso(now),
        }


    def alert(state, problems):
        active = state["problems"]
        for key, msg in problems.items():
            if key not in active:
                ntfy("alerts", "Music pipeline problem", msg, "warning", "high")
                log(f"problem: {msg}")
        for key in set(active) - set(problems):
            ntfy("alerts", "Music pipeline recovered", f"Resolved: {active[key]}", "white_check_mark")
            log(f"resolved: {active[key]}")
        state["problems"] = problems


    class Handler(BaseHTTPRequestHandler):
        def do_GET(self):
            with lock:
                body = json.dumps(status, ensure_ascii=False).encode()
                ok = status.get("health") != "degraded"
            if self.path.startswith("/status"):
                code = 200
            elif self.path.startswith("/health"):
                code = 200 if ok else 503
            else:
                self.send_error(404)
                return
            self.send_response(code)
            self.send_header("Content-Type", "application/json; charset=utf-8")
            self.send_header("Content-Length", str(len(body)))
            self.end_headers()
            self.wfile.write(body)

        def log_message(self, *args):
            pass


    def main():
        global status
        server = ThreadingHTTPServer(("127.0.0.1", ${toString port}), Handler)
        threading.Thread(target=server.serve_forever, daemon=True).start()
        state = load_state()
        while True:
            try:
                problems, new_status = evaluate(state)
                alert(state, problems)
                save_state(state)
                with lock:
                    status = new_status
            except Exception as e:
                log(f"error: {e}")
            time.sleep(POLL_SECS)


    main()
  '';
in
{
  systemd.services.music-pipeline = {
    description = "Music pipeline: per-album ntfy, status endpoint and alerts";
    wantedBy = [ "multi-user.target" ];
    after = [ "network.target" "ntfy-sh.service" "syncthing.service" ];

    serviceConfig = {
      ExecStart = "${script}";
      User = "weast";
      # Same directory as the old music-staging-watcher, so its list of
      # announced albums carries over (migrated on first start)
      StateDirectory = "music-staging-watcher";
      Restart = "always";
      RestartSec = "10s";
    };
  };
}
