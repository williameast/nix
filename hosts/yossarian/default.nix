# Configuration for yossarian (laptop with Intel CometLake-U GT2)
{ config, pkgs, lib, inputs, ... }:

{
  imports = [
    ../common.nix
    ../../modules/core
    ../../modules/desktop
    ../../modules/dev
    ../../modules/media
    # ../../modules/games       # Uncomment if you want games on laptop
    # ../../modules/modelling   # Uncomment if you want CAD on laptop
    ../../modules/machines/yossarian.nix
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

  # Syncthing configuration for yossarian (laptop)
  services.syncthing.settings = {
    # Define other devices to sync with
    devices = {
      "orr" = {
        # Get device ID from: syncthing --device-id
        # Run on orr, then paste ID here
        id = "XXXXXXX-XXXXXXX-XXXXXXX-XXXXXXX-XXXXXXX-XXXXXXX-XXXXXXX-XXXXXXX";
      };
    };

    # Define folders to sync
    folders = {
      "org" = {
        path = "${config.home.homeDirectory}/org";
        devices = [ "orr" ];
        ignorePerms = false; # Preserve permissions
      };
      "music" = {
        path = "${config.home.homeDirectory}/Music";
        devices = [ "orr" ];
        ignorePerms = false;
      };
    };
  };
}
