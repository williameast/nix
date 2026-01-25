# Configuration for orr (Pop!_OS workstation with AMD R9 290)
{
  config,
  pkgs,
  lib,
  inputs,
  ...
}:

{
  imports = [
    ../common.nix
    ../../modules/core
    ../../modules/desktop
    ../../modules/dev
    ../../modules/media
    ../../modules/games
    ../../modules/modelling
    ../../modules/work
    ../../modules/machines/orr.nix
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

  # Syncthing configuration for orr (desktop workstation)
  services.syncthing.settings = {
    # Define other devices to sync with
    devices = {
      "yossarian" = {
        # Get device ID from: syncthing --device-id
        # Run on yossarian, then paste ID here
        id = "XXXXXXX-XXXXXXX-XXXXXXX-XXXXXXX-XXXXXXX-XXXXXXX-XXXXXXX-XXXXXXX";
      };
    };

    # Define folders to sync
    folders = {
      "org" = {
        path = "${config.home.homeDirectory}/org";
        devices = [ "yossarian" ];
        ignorePerms = false; # Preserve permissions
      };
      "music" = {
        path = "${config.home.homeDirectory}/Music";
        devices = [ "yossarian" ];
        ignorePerms = false;
      };
    };
  };
  # Machine-specific files
  home.file.".config/emacs/.local/etc/bookmarks".source = ./files/emacs/bookmarks;
}
