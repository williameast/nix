# Sonarr, Radarr and Prowlarr on milo; the seedbox (ultracc) only downloads and seeds
#
#   Prowlarr (indexers) → Sonarr/Radarr ──HTTPS XML-RPC──→ rtorrent on ultracc
#                                                            │ ~/bin/red-staging.py hardlinks
#                                                            │ finished torrents into ~/arr-outbox
#   /mnt/bulk/seedbox/outbox  ←──Syncthing "arr-outbox"──────┘
#        │ seedbox-handoff (below): once Syncthing has every file of a release
#        ▼ and it has been quiet for 2 minutes, hardlink it into
#   /mnt/bulk/seedbox/complete/<label>/<release>
#        │ Sonarr/Radarr remote path mapping:
#        │   /home/weast/downloads/rtorrent/ → /mnt/bulk/seedbox/complete/
#        ▼ import by hardlink (same filesystem, no extra space)
#   /mnt/bulk/tv-shows, /mnt/bulk/movies → Jellyfin
#
# When a torrent has seeded enough, red-staging.py removes it and its outbox
# entry; Syncthing deletes it here and seedbox-handoff removes the matching
# complete/ entry. The library copies are separate hardlinks and stay.
#
# Not declarative (set in each app's web UI, stored in its database): download
# client, remote path mapping, root folders, quality profiles, Prowlarr's
# indexers (TorrentDay, Blutopia) and its app sync to Sonarr/Radarr.
{ config, pkgs, lib, ... }:

let
  topology = import ../../home/syncthing-topology.nix { inherit lib; };

  # Sonarr and Radarr run as weast so they can hardlink files Syncthing writes
  # (weast:users) into the library, which is owned by weast too
  user = "weast";
  group = "users";

  outbox = topology.sharedFolders.arr-outbox.pathOverrides.milo;
  complete = "/mnt/bulk/seedbox/complete";
  syncthingUrl = "http://127.0.0.1:8384";
  syncthingConfig = "${config.services.syncthing.configDir}/config.xml";

  handoff = pkgs.writeScript "seedbox-handoff" ''
    #!${pkgs.python3}/bin/python3
    import json, os, re, shutil, time, urllib.request

    OUTBOX = "${outbox}"
    COMPLETE = "${complete}"
    QUIET_SECS = 120
    POLL_SECS = 30


    def log(msg):
        print(msg, flush=True)


    def needed():
        """Paths in arr-outbox that Syncthing still has to fetch."""
        with open("${syncthingConfig}") as f:
            key = re.search(r"<apikey>(.*?)</apikey>", f.read()).group(1)
        req = urllib.request.Request(
            "${syncthingUrl}/rest/db/need?folder=arr-outbox&perpage=100000",
            headers={"X-API-Key": key})
        need = json.load(urllib.request.urlopen(req, timeout=30))
        return {f["name"] for k in ("progress", "queued", "rest") for f in need.get(k) or []}


    def releases(root):
        """(label, release) pairs one level below each label directory."""
        out = set()
        for label in os.listdir(root) if os.path.isdir(root) else []:
            d = os.path.join(root, label)
            if os.path.isdir(d):
                out |= {(label, n) for n in os.listdir(d)
                        if not n.startswith((".syncthing.", ".handoff."))}
        return out


    def newest_mtime(path):
        newest = os.lstat(path).st_mtime
        for root, dirs, files in os.walk(path):
            for n in dirs + files:
                try:
                    newest = max(newest, os.lstat(os.path.join(root, n)).st_mtime)
                except FileNotFoundError:
                    pass
        return newest


    def link_tree(src, dest):
        """Hardlink src (file or directory) to dest via a temp name, skipping Syncthing temp files."""
        tmp = os.path.join(os.path.dirname(dest), ".handoff." + os.path.basename(dest))
        shutil.rmtree(tmp, ignore_errors=True)
        if os.path.isdir(src):
            shutil.copytree(src, tmp, copy_function=os.link,
                            ignore=shutil.ignore_patterns(".syncthing.*"))
        else:
            os.link(src, tmp)
        os.rename(tmp, dest)


    def run():
        need = needed()
        os.makedirs(COMPLETE, exist_ok=True)
        arrived = releases(OUTBOX)
        for label, name in sorted(arrived - releases(COMPLETE)):
            rel = f"{label}/{name}"
            src = os.path.join(OUTBOX, label, name)
            if any(n == rel or n.startswith(rel + "/") for n in need):
                continue
            if time.time() - newest_mtime(src) < QUIET_SECS:
                continue
            os.makedirs(os.path.join(COMPLETE, label), exist_ok=True)
            link_tree(src, os.path.join(COMPLETE, label, name))
            log(f"ready for import: {rel}")
        for label, name in sorted(releases(COMPLETE) - arrived):
            path = os.path.join(COMPLETE, label, name)
            shutil.rmtree(path) if os.path.isdir(path) else os.remove(path)
            log(f"removed (gone from seedbox): {label}/{name}")


    while True:
        try:
            run()
        except Exception as e:
            log(f"error: {e}")
        time.sleep(POLL_SECS)
  '';
in
{
  services.sonarr = {
    enable = true;
    inherit user group;
    openFirewall = true;  # 8989, LAN
  };

  services.radarr = {
    enable = true;
    inherit user group;
    openFirewall = true;  # 7878, LAN
  };

  services.prowlarr = {
    enable = true;
    openFirewall = true;  # 9696, LAN
  };

  # Group-writable files, so imports into the library stay editable for weast:users
  systemd.services.sonarr.serviceConfig.UMask = lib.mkForce "0002";
  systemd.services.radarr.serviceConfig.UMask = lib.mkForce "0002";

  systemd.services.seedbox-handoff = {
    description = "Hand finished seedbox downloads to Sonarr/Radarr once fully synced";
    wantedBy = [ "multi-user.target" ];
    after = [ "syncthing.service" ];
    serviceConfig = {
      # As root ("+"): the Syncthing activation script creates the parent
      # /mnt/bulk/seedbox owned by root, and tmpfiles refuses to fix it up
      # (weast-owned /mnt/bulk above it is an "unsafe path transition")
      ExecStartPre = "+${pkgs.coreutils}/bin/install -d -o ${user} -g ${group} -m 0775 ${dirOf complete} ${complete}";
      ExecStart = "${handoff}";
      User = user;
      Group = group;
      UMask = "0002";
      Restart = "always";
      RestartSec = "10s";
    };
  };
}
