# Jellyfin media server
{ config, pkgs, lib, ... }:

{
  services.jellyfin = {
    enable = true;
    openFirewall = true;  # Opens port 8096
  };

  # After first boot, configure libraries in web UI at: http://milo:8096
  # Media is stored on /mnt/vault-new/ (tv-shows, movies, music)

  # Ensure jellyfin can read the media directories
  systemd.services.jellyfin.serviceConfig.ReadOnlyPaths = [ "/mnt/vault-new" ];
}
