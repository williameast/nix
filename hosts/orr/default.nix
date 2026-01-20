# Configuration for orr (Pop!_OS workstation with AMD R9 290)
{ config, pkgs, lib, inputs, ... }:

{
  imports = [
    ../common.nix
    ../../modules/core
    ../../modules/desktop
    ../../modules/dev
    ../../modules/media
    ../../modules/games
    ../../modules/modelling
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
}
