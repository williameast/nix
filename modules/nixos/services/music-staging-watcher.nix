# Music staging watcher
# Watches /mnt/vault-new/staging/music for albums arriving via Syncthing and
# sends one ntfy notification per album ("<album> is ready for import") once
# Syncthing has every file of it and nothing has been written for 2 minutes.
{ config, pkgs, lib, ... }:

let
  ntfyUrl = "http://localhost:2586/music";
  watchDir = "/mnt/vault-new/staging/music";
  syncthingUrl = "http://127.0.0.1:8384";
  syncthingConfig = "${config.services.syncthing.configDir}/config.xml";
  syncthingFolder = "music-staging";

  script = pkgs.writeScript "music-staging-watcher" ''
    #!${pkgs.python3}/bin/python3
    import json, os, re, sys, time, urllib.parse, urllib.request

    WATCH_DIR = "${watchDir}"
    STATE = os.path.join(os.environ["STATE_DIRECTORY"], "notified.json")
    QUIET_SECS = 120
    POLL_SECS = 30
    IGNORE = {".stfolder", ".stversions", ".stignore"}

    def log(msg):
        print(msg, flush=True)

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

    def syncthing_needed():
        """Names Syncthing still has to pull in the staging folder."""
        with open("${syncthingConfig}") as f:
            key = re.search(r"<apikey>(.*?)</apikey>", f.read()).group(1)
        url = "${syncthingUrl}/rest/db/need?folder=${syncthingFolder}&perpage=100000"
        req = urllib.request.Request(url, headers={"X-API-Key": key})
        need = json.load(urllib.request.urlopen(req, timeout=30))
        return {f["name"] for k in ("progress", "queued", "rest")
                for f in need.get(k) or []}

    def notify(album):
        req = urllib.request.Request(
            "${ntfyUrl}", data=f"{album} is ready for import".encode(),
            headers={"Title": "Ready for import", "Tags": "musical_note"})
        urllib.request.urlopen(req, timeout=30).read()

    def save(notified):
        with open(STATE + ".tmp", "w") as f:
            json.dump(sorted(notified), f, indent=1, ensure_ascii=False)
        os.replace(STATE + ".tmp", STATE)

    if os.path.exists(STATE):
        with open(STATE) as f:
            notified = set(json.load(f))
    else:
        # First start: treat whatever is already in staging as announced.
        notified = albums()
        save(notified)
        log(f"initialised with {len(notified)} existing albums")

    while True:
        try:
            present = albums()
            # Forget albums that were imported/removed, so a re-delivery notifies again.
            changed = bool(notified - present)
            notified &= present
            new = sorted(present - notified)
            needed = syncthing_needed() if new else set()
            for album in new:
                if any(n == album or n.startswith(album + "/") for n in needed):
                    continue
                if time.time() - newest_mtime(os.path.join(WATCH_DIR, album)) < QUIET_SECS:
                    continue
                notify(album)
                log(f"ready: {album}")
                notified.add(album)
                changed = True
            if changed:
                save(notified)
        except Exception as e:
            log(f"error: {e}")
        time.sleep(POLL_SECS)
  '';
in
{
  systemd.services.music-staging-watcher = {
    description = "Notify via ntfy when an album has fully arrived in music staging";
    wantedBy = [ "multi-user.target" ];
    after = [ "network.target" "ntfy-sh.service" "syncthing.service" ];

    serviceConfig = {
      ExecStart = "${script}";
      User = "weast";
      StateDirectory = "music-staging-watcher";
      Restart = "on-failure";
      RestartSec = "10s";
    };
  };
}
