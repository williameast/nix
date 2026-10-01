# ntfy desktop notifications
# Subscribes to ntfy topics on milo and shows desktop notifications via notify-send.
{ config, pkgs, lib, ... }:

let
  ntfyBase = "http://milo:2586";

  # Topics to subscribe to
  topics = [ "music" "alerts" "backups" ];

  # Script that subscribes to the ntfy JSON stream and calls notify-send
  script = pkgs.writeShellScript "ntfy-subscribe" ''
    TOPICS="${lib.concatStringsSep "," topics}"

    # ntfy supports subscribing to multiple topics with comma separation
    ${pkgs.curl}/bin/curl -s -N \
      "${ntfyBase}/$TOPICS/json" |
      while read -r line; do
        EVENT=$(echo "$line" | ${pkgs.jq}/bin/jq -r '.event // empty')
        [ "$EVENT" != "message" ] && continue

        TITLE=$(echo "$line" | ${pkgs.jq}/bin/jq -r '.title // .topic')
        MSG=$(echo "$line" | ${pkgs.jq}/bin/jq -r '.message // empty')
        PRIORITY=$(echo "$line" | ${pkgs.jq}/bin/jq -r '.priority // 3')

        case "$PRIORITY" in
          1|2) URGENCY="low" ;;
          4|5) URGENCY="critical" ;;
          *)   URGENCY="normal" ;;
        esac

        ${pkgs.libnotify}/bin/notify-send -u "$URGENCY" "$TITLE" "$MSG"
      done
  '';
in
{
  systemd.user.services.ntfy-subscribe = {
    Unit = {
      Description = "Subscribe to ntfy topics for desktop notifications";
      After = [ "graphical-session.target" ];
      PartOf = [ "graphical-session.target" ];
    };

    Service = {
      ExecStart = "${script}";
      Restart = "on-failure";
      RestartSec = "10s";
    };

    Install = {
      WantedBy = [ "graphical-session.target" ];
    };
  };
}
