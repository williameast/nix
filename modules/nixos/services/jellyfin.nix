# Jellyfin media server
{ config, pkgs, lib, ... }:

{
  services.jellyfin = {
    enable = true;
    openFirewall = true;  # Opens port 8096
  };

  # After first boot, configure libraries in web UI at: http://milo:8096
  # Media is stored on /mnt/vault-new/ (tv-shows, movies, music)

  # Allow jellyfin to read media files owned by weast:users
  users.users.jellyfin.extraGroups = [ "users" ];
}
