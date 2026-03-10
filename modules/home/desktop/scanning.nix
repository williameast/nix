# Scanner client for desktop machines
# The Brother DCP-L2520DW is found via airscan/WSD directly on the LAN —
# no drivers or saned needed. Pop!_OS ships simple-scan + sane-airscan already.
# Set simple-scan's save folder to ~/org/scans/ so files sync everywhere.
#
# NOTE: do NOT install pkgs.simple-scan here — the nix version uses its own
# sane-backends without airscan, shadowing the system simple-scan that works.
{ config, pkgs, lib, ... }:

{
  # Ensure the scan output dir exists in org so Syncthing picks it up
  home.activation.createScanDir = config.lib.dag.entryAfter ["writeBoundary"] ''
    mkdir -p "${config.home.homeDirectory}/org/scans"
  '';
}
