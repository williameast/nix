# Core modules - always included in every host configuration
{ config, pkgs, lib, ... }:

{
  imports = [
    ./xdg.nix
    ./shell.nix
    ./git.nix
    ./cli-tools.nix
  ];
}
