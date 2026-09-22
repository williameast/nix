# Work modules - applications needed for work
{ config, pkgs, lib, ... }:

{
  home.packages = with pkgs; [
    # Video conferencing
    zoom-us
  ];
}
