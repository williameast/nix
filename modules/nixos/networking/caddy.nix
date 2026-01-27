# Caddy reverse proxy with automatic HTTPS
{ config, pkgs, lib, ... }:

{
  services.caddy = {
    enable = true;

    # Example configuration - customize for your services
    virtualHosts = {
      # Example: jellyfin.yourdomain.com
      # "jellyfin.yourdomain.com" = {
      #   extraConfig = ''
      #     reverse_proxy localhost:8096
      #   '';
      # };

      # Example: navidrome.yourdomain.com
      # "navidrome.yourdomain.com" = {
      #   extraConfig = ''
      #     reverse_proxy localhost:4533
      #   '';
      # };
    };
  };

  # Open HTTP and HTTPS ports
  networking.firewall.allowedTCPPorts = [ 80 443 ];
}
