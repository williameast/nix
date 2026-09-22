# Machine-specific configuration for orr (Pop!_OS workstation)
# Includes 42 Berlin tools and other machine-specific packages
{ config, pkgs, lib, inputs, ... }:

{
  home.packages = with pkgs; [
    # 42 Berlin specific tools
    valgrind
    gdb

    # File browser
    sushi

    # Utilities
    gnutls
    powertop
    ddrescue # Data recovery from failing drives
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

    # Claude Desktop
    inputs.claude-desktop.packages.${pkgs.system}.claude-desktop-fhs
  ];

  # Syncthing service
  services.syncthing.enable = true;

}
