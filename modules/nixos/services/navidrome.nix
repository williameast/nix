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
      MusicFolder = "/mnt/vault-new/music";

      # Data folder for cache, DB, etc.
      DataFolder = "/var/lib/navidrome";
    };
  };

  # Allow navidrome to read music files owned by weast
  users.users.navidrome.extraGroups = [ "users" ];

  # Open firewall port
  networking.firewall.allowedTCPPorts = [ 4533 ];
}
