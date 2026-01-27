# Configuration for milo (server - minimal headless setup)
{ config, pkgs, lib, inputs, ... }:

let
  # Import syncthing topology configuration
  topology = import ../../modules/home/syncthing-topology.nix { inherit lib; };
  hostname = "milo";

  # Get list of devices this host should know about
  knownDevices = topology.getDevicesForHost hostname;

  # Build device configuration (all devices we might sync with)
  devices = lib.listToAttrs (map (name: {
    name = name;
    value = { id = topology.machines.${name}.deviceId; };
  }) knownDevices);

  # Build folder configuration (per-folder device lists)
  folders = lib.mapAttrs (folderName: folderConfig: {
    path = "${config.home.homeDirectory}/${folderConfig.path}";
    devices = topology.getDevicesForFolder hostname folderName;
    ignorePerms = folderConfig.ignorePerms;
    type = folderConfig.type or "sendreceive";  # Default to sendreceive
  } // lib.optionalAttrs (folderConfig ? patterns) {
    # Add ignore patterns if specified (for file filtering like .torrent only)
    ignorePatterns = folderConfig.patterns;
  }) topology.sharedFolders;

in {
  imports = [
    ../common.nix
    ../../modules/home/core/shell.nix
    ../../modules/home/core/git.nix
    ../../modules/home/core/cli-tools.nix
    ../../modules/home/core/syncthing.nix
    ../../modules/home/secrets.nix
    ../../modules/home/machines/milo.nix
  ];

  # Required for non-NixOS systems
  targets.genericLinux.enable = true;

  # No desktop, no GPU - server only

  # Syncthing configuration (topology defined in modules/syncthing-topology.nix)
  # In hub-and-spoke mode, milo is the hub and syncs with all spokes
  services.syncthing.settings = {
    inherit devices folders;
  };
}
