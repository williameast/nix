# Machine-specific configuration for orr (Pop!_OS workstation)
# Includes 42 Berlin tools and other machine-specific packages
{ config, pkgs, lib, ... }:

{
  home.packages = with pkgs; [
    # 42 Berlin specific tools
    norminette
    valgrind
    gdb

    # File browser
    sushi

    # Communications
    thunderbird

    # Utilities
    gnutls
    powertop
    ddrescue # Data recovery from failing drives
    wine
    autokey

    # Network
    tailscale
    mullvad-vpn

    # USB/Hardware
    libusb1

    # SDR
    gqrx

    # Secrets
    keepassxc

    # Torrenting
    intermodal # Create .torrent files

  ];

  # 42-specific shell aliases
  programs.zsh.shellAliases = {
    ccw = "cc -Wextra -Werror -Wall";
    norm = "norminette";
  };

  # Syncthing service
  services.syncthing.enable = true;
}
