# Scanner client for desktop machines
# The Brother DCP-L2520DW is found via SANE brscan4 driver on the LAN.
# Requires hardware.sane + brscan4 at NixOS level (modules/nixos/services/scanning.nix).
# Set simple-scan's save folder to ~/org/scans/ so files sync everywhere.
{ config, pkgs, lib, ... }:

{
  home.packages = with pkgs; [
    simple-scan  # GUI scanning app (uses SANE backend)
  ];

  # Ensure the scan output dir exists in org so Syncthing picks it up
  home.activation.createScanDir = config.lib.dag.entryAfter ["writeBoundary"] ''
    mkdir -p "${config.home.homeDirectory}/org/scans"
  '';
}
