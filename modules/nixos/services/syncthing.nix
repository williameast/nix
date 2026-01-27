# Syncthing for the weast user
{ config, pkgs, lib, ... }:

{
  services.syncthing = {
    enable = true;
    user = "weast";
    dataDir = "/home/weast";
    configDir = "/home/weast/.config/syncthing";

    # Web UI settings
    guiAddress = "0.0.0.0:8384";  # Change to 127.0.0.1:8384 if you only want local access

    # Override devices and folders to use declarative config
    overrideDevices = true;
    overrideFolders = true;

    settings = {
      # Devices and folders will be configured based on syncthing-topology.nix
      # Import that configuration in your host config
      devices = {};
      folders = {};
    };
  };

  # Open firewall for syncthing
  networking.firewall.allowedTCPPorts = [ 8384 22000 ];
  networking.firewall.allowedUDPPorts = [ 22000 21027 ];
}
