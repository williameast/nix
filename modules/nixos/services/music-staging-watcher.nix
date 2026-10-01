# Music staging watcher
# Watches /mnt/vault-new/staging/music for new files arriving via Syncthing
# and sends an ntfy notification when they settle (no new writes for 2 minutes).
{ config, pkgs, lib, ... }:

let
  ntfyBase = "http://localhost:2586";
  watchDir = "/mnt/vault-new/staging/music";

  script = pkgs.writeShellScript "music-staging-watcher" ''
    # Wait for new files, then debounce: after 2 minutes of quiet, notify once.
    ${pkgs.inotify-tools}/bin/inotifywait -m -r \
      -e close_write,moved_to \
      --exclude '\.(tmp|syncthing)' \
      "${watchDir}" |
      while read -r dir event file; do
        # On first event, wait for quiet period then notify
        while read -t 120 -r _dir _event _file; do
          : # drain events until 120s of silence
        done

        ${pkgs.curl}/bin/curl -s \
          -H "Title: Music ready for import" \
          -H "Tags: musical_note" \
          -d "New music has arrived in staging and is ready for beet import." \
          ${ntfyBase}/music

      done
  '';
in
{
  systemd.services.music-staging-watcher = {
    description = "Watch music staging for new files and notify via ntfy";
    wantedBy = [ "multi-user.target" ];
    after = [ "network.target" "ntfy-sh.service" ];

    serviceConfig = {
      ExecStart = "${script}";
      User = "weast";
      Restart = "on-failure";
      RestartSec = "10s";
    };
  };
}
