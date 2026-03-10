# Scanner client for desktop machines
# Connects to milo's saned over the network — no local driver needed
# Set simple-scan's save folder to ~/org/scans/ so files sync everywhere
{ config, pkgs, lib, ... }:

{
  home.packages = [ pkgs.simple-scan ];

  # Point SANE's net backend at milo
  home.sessionVariables.SANE_NET_HOSTS = "milo";
}
