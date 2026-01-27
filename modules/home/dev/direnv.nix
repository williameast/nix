# Direnv for per-project environment management
{ config, pkgs, lib, ... }:

{
  programs.direnv = {
    enable = true;
    nix-direnv.enable = true;  # Better nix integration
  };

  home.packages = with pkgs; [
    nix-direnv
  ];
}
