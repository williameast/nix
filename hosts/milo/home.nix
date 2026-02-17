# Configuration for milo (server - minimal headless setup)
{ config, pkgs, lib, inputs, ... }:

{
  imports = [
    ../common.nix
    ../../modules/home/core/shell.nix
    ../../modules/home/core/git.nix
    ../../modules/home/core/cli-tools.nix
    ../../modules/home/secrets.nix
    ../../modules/home/machines/milo.nix
  ];

  # Required for non-NixOS systems
  targets.genericLinux.enable = true;

  # No desktop, no GPU - server only
  # Syncthing is handled by the NixOS system service (modules/nixos/services/syncthing.nix)
}
