# Configuration for yossarian (laptop with Intel CometLake-U GT2)
{ config, pkgs, lib, inputs, ... }:

let
  # Syncthing configuration (using topology as single source of truth)
  topology = import ../../modules/home/syncthing-topology.nix { inherit lib; };
  syncConfig = topology.buildSyncthingConfig {
    hostname = "yossarian";
    homeDir = config.home.homeDirectory;
  };

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

  # Syncthing configuration (topology defined in modules/home/syncthing-topology.nix)
  services.syncthing.settings = {
    inherit (syncConfig) devices folders;
  };

  # Auto-create syncthing folders
  systemd.user.tmpfiles.rules = syncConfig.tmpfiles;
}
