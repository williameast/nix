# ntfy.sh - push notification server (LAN-only via Tailscale)
{ config, pkgs, lib, ... }:

{
  services.ntfy-sh = {
    enable = true;
    settings = {
      base-url = "http://milo:2586";
      listen-http = ":2586";
      behind-proxy = false;
    };
  };

  networking.firewall.allowedTCPPorts = [ 2586 ];
}
