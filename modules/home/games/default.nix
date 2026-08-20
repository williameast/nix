# Games - Steam and gaming utilities
{ config, pkgs, lib, inputs, ... }:

{
  home.packages = with pkgs; [
    steam
  ];
}
