# Configuration for orr (Pop!_OS workstation with AMD R9 290)
{
  config,
  pkgs,
  lib,
  inputs,
  ...
}:

let
  # Syncthing configuration (using topology as single source of truth)
  topology = import ../../modules/home/syncthing-topology.nix { inherit lib; };
  syncConfig = topology.buildSyncthingConfig {
    hostname = "orr";
    homeDir = config.home.homeDirectory;
  };

in {
  imports = [
    ../common.nix
    ../../modules/home/core
    ../../modules/home/desktop
    ../../modules/home/dev
    ../../modules/home/media
    ../../modules/home/games
    ../../modules/home/modelling
    ../../modules/home/work
    ../../modules/home/machines/orr.nix
  ];

  # Required for non-NixOS systems (Pop!_OS)
  targets.genericLinux.enable = true;

  # XDG data dirs for nix-installed apps to show in launcher
  xdg.systemDirs.data = [
    "${config.home.homeDirectory}/.nix-profile/share"
  ];

  # AMD R9 290 specific settings
  home.sessionVariables = {
    # VA-API driver for hardware video acceleration
    LIBVA_DRIVER_NAME = "radeonsi";
    # Force EGL for better WebGL support
    MOZ_X11_EGL = "1";
  };

  # Syncthing configuration (topology defined in modules/home/syncthing-topology.nix)
  services.syncthing.settings = {
    inherit (syncConfig) devices folders;
  };

  # Auto-create syncthing folders
  systemd.user.tmpfiles.rules = syncConfig.tmpfiles;

  # Machine-specific files
  home.file.".config/emacs/.local/etc/bookmarks".source = ./files/emacs/bookmarks;
}
