# Machine-specific configuration for milo (server)
# Minimal headless setup for Proxmox or similar
{ config, pkgs, lib, ... }:

{
  home.packages = with pkgs; [
    # Monitoring
    htop
    btop

    # Networking
    curl
    wget

    # File management
    tree
    unzip

    # System
    tmux

    # Containers
    docker
    docker-compose
  ];
}
