# Torrent file watcher
# Watches ~/Downloads for .torrent files and copies them to ~/torrentfiles/
# which is synced via Syncthing to milo → ultracc for automatic downloading.
{ config, pkgs, lib, ... }:

let
  watchDir = "${config.home.homeDirectory}/Downloads";
  destDir = "${config.home.homeDirectory}/torrentfiles";

  script = pkgs.writeShellScript "torrent-watcher" ''
    mkdir -p "${watchDir}" "${destDir}"

    # Copy any .torrent files that arrived while the service was stopped
    for f in "${watchDir}"/*.torrent; do
      [ -f "$f" ] && cp "$f" "${destDir}/"
    done

    ${pkgs.inotify-tools}/bin/inotifywait -m -e close_write,moved_to "${watchDir}" |
      while read -r dir event file; do
        if [[ "$file" == *.torrent ]]; then
          cp "${watchDir}/$file" "${destDir}/"
        fi
      done
  '';
in
{
  systemd.user.services.torrent-watcher = {
    Unit = {
      Description = "Copy .torrent files from Downloads to torrentfiles";
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
