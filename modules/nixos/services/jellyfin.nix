# Jellyfin media server
{ config, pkgs, lib, ... }:

{
  services.jellyfin = {
    enable = true;
    openFirewall = true;  # Opens port 8096
  };

  # Jellyfin user needs access to media directories
  # Add your media directories here
  # users.users.jellyfin.extraGroups = [ "media" ];
}
