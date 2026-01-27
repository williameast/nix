# Work modules - applications needed for work
{ config, pkgs, lib, ... }:

{
  home.packages = with pkgs; [
    # German eID authentication app
    ausweisapp
  ];
}
