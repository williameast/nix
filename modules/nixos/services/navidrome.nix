# Navidrome music server
{ config, pkgs, lib, ... }:

{
  services.navidrome = {
    enable = true;
    settings = {
      # Listen on all interfaces (not just localhost)
      Address = "0.0.0.0";

      # Port for web interface
      Port = 4533;

      # Music folder on Btrfs vault (redundant storage)
      MusicFolder = "/mnt/vault/music";

      # Data folder for cache, DB, etc.
      DataFolder = "/var/lib/navidrome";
    };
  };

  # Open firewall port
  networking.firewall.allowedTCPPorts = [ 4533 ];
}
