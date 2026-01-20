# Configuration for milo (server - minimal headless setup)
{ config, pkgs, lib, inputs, ... }:

{
  imports = [
    ../common.nix
    ../../modules/core/shell.nix
    ../../modules/core/git.nix
    ../../modules/core/cli-tools.nix
    ../../modules/machines/milo.nix
  ];

  # Required for non-NixOS systems
  targets.genericLinux.enable = true;

  # No desktop, no GPU - server only
}
