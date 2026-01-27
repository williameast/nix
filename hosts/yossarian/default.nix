# Configuration for yossarian (laptop with Intel CometLake-U GT2)
{ config, pkgs, lib, inputs, ... }:

let
  # Import syncthing topology configuration
  topology = import ../../modules/home/syncthing-topology.nix { inherit lib; };
  hostname = "yossarian";

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
    ../../modules/home/core
    ../../modules/home/desktop
    ../../modules/home/dev
    ../../modules/home/media
    # ../../modules/home/games       # Uncomment if you want games on laptop
    # ../../modules/home/modelling   # Uncomment if you want CAD on laptop
    ../../modules/home/machines/yossarian.nix
  ];

  # Required for non-NixOS systems
  targets.genericLinux.enable = true;

  # XDG data dirs for nix-installed apps to show in launcher
  xdg.systemDirs.data = [
    "${config.home.homeDirectory}/.nix-profile/share"
  ];

  # Intel integrated GPU settings
  home.sessionVariables = {
    # VA-API driver for hardware video acceleration
    LIBVA_DRIVER_NAME = "iHD";
    # Force EGL for better WebGL support
    MOZ_X11_EGL = "1";
  };

  # Syncthing configuration (topology defined in modules/syncthing-topology.nix)
  services.syncthing.settings = {
    inherit devices folders;
  };
}
