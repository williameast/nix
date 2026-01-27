# Navidrome music server
{ config, pkgs, lib, ... }:

{
  services.navidrome = {
    enable = true;
    settings = {
      # Port for web interface
      Port = 4533;

      # Music folder - adjust to your setup
      MusicFolder = "/var/lib/navidrome/music";

      # Data folder for cache, DB, etc.
      DataFolder = "/var/lib/navidrome";
    };
  };

  # Open firewall port
  networking.firewall.allowedTCPPorts = [ 4533 ];
}
