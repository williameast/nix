# Jellyfin media server
{ config, pkgs, lib, ... }:

{
  services.jellyfin = {
    enable = true;
    openFirewall = true;  # Opens port 8096
  };

  # Jellyfin user needs read access to media directory
  # Films are stored at: /mnt/media/films (4TB USB drive)
  # After first boot, configure libraries in web UI at: http://milo:8096

  # Ensure jellyfin can read the media directory
  systemd.services.jellyfin.serviceConfig.ReadOnlyPaths = [ "/mnt/media" ];
}
