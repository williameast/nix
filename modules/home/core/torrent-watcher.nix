# Torrent file watcher
# Watches ~/Downloads for .torrent files and moves them to ~/torrentfiles/
# which is synced via Syncthing to milo → ultracc for automatic downloading.
{ config, pkgs, lib, ... }:

let
  watchDir = "${config.home.homeDirectory}/Downloads";
  destDir = "${config.home.homeDirectory}/torrentfiles";

  script = pkgs.writeShellScript "torrent-watcher" ''
    mkdir -p "${watchDir}" "${destDir}"

    # Move any .torrent files that arrived while the service was stopped
    for f in "${watchDir}"/*.torrent; do
      [ -f "$f" ] && mv "$f" "${destDir}/"
    done

    ${pkgs.inotify-tools}/bin/inotifywait -m -e close_write,moved_to "${watchDir}" |
      while read -r dir event file; do
        if [[ "$file" == *.torrent ]]; then
          mv "${watchDir}/$file" "${destDir}/"
        fi
      done
  '';
in
{
  systemd.user.services.torrent-watcher = {
    Unit = {
      Description = "Move .torrent files from Downloads to torrentfiles";
      After = [ "default.target" ];
    };

    Service = {
      ExecStart = "${script}";
      Restart = "on-failure";
      RestartSec = "5s";
    };

    Install = {
      WantedBy = [ "default.target" ];
    };
  };
}
