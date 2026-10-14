# FileBrowser - share large files with people outside the tailnet
#
# Files live in /mnt/vault-new/share. Manage them in the web UI at
# https://milo.quoll-bleak.ts.net:8443 (tailnet only), or copy them in over
# SSH/rsync. To share, select a file or folder → Share (optional password
# and expiry).
#
# Tailscale Funnel publishes https://milo.quoll-bleak.ts.net, but only the
# paths a share link needs (/share, /api/public, /static); the login page
# and the rest of the app stay on the tailnet. Share links are generated
# with the admin port, so drop ":8443" before sending one.
#
# First start: the admin password is in `journalctl -u filebrowser`
# ("randomly generated password"); change it under Settings.
#
# One-time tailnet setup (admin console): DNS → enable HTTPS certificates,
# and allow Funnel for milo in the access controls
# ("nodeAttrs": [{ "target": ["autogroup:member"], "attr": ["funnel"] }]).
{ config, lib, ... }:

let
  port = 8085;
  root = "/mnt/vault-new/share";
  backend = "http://127.0.0.1:${toString port}";
  tailscale = "${config.services.tailscale.package}/bin/tailscale";
in
{
  services.filebrowser = {
    enable = true;
    settings = {
      address = "127.0.0.1";
      inherit port root;
    };
  };

  # Share folder is writable by weast (group users) as well as FileBrowser,
  # so files can also be copied in over SSH.
  systemd.tmpfiles.settings.filebrowser.${root}.d = lib.mkForce {
    user = "filebrowser";
    group = "users";
    mode = "2775";
  };
  systemd.services.filebrowser = {
    unitConfig.RequiresMountsFor = [ root ];
    serviceConfig.UMask = lib.mkForce "0002";
  };

  # Tailscale Serve/Funnel config, applied on every boot. Replaces any
  # serve config set by hand on milo.
  systemd.services.tailscale-funnel = {
    description = "Publish FileBrowser share links with Tailscale Funnel";
    after = [ "tailscaled.service" "filebrowser.service" ];
    wants = [ "tailscaled.service" ];
    wantedBy = [ "multi-user.target" ];
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
      # tailscaled may not be logged in yet at boot
      Restart = "on-failure";
      RestartSec = 30;
      # `tailscale funnel` waits for the admin console when Funnel is off
      TimeoutStartSec = 60;
    };
    script = ''
      ${tailscale} serve reset
      # Whole app, tailnet only
      ${tailscale} serve --bg --https=8443 ${backend}
      # Public: share pages and the downloads behind them
      for path in /share /api/public /static; do
        ${tailscale} funnel --bg --https=443 --set-path "$path" "${backend}$path"
      done
    '';
  };
}
