# Common configuration shared across all hosts
{ config, pkgs, ... }:

{
  home.username = "weast";
  home.homeDirectory = "/home/weast";

  # Match your current stateVersion from old config
  home.stateVersion = "24.11";

  # Let Home Manager manage itself
  programs.home-manager.enable = true;
}
