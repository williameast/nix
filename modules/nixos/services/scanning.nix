# Scanning service for Brother DCP-L2520DW
# - brscan4: SANE backend driver so scanimage/simple-scan can talk to the printer
# - saned: exposes the scanner over the network so desktop machines can scan remotely
#
# The printer's Scan button is handled by scan-to-paperless.nix (brscan-skey).
{ config, pkgs, lib, ... }:
{
  hardware.sane = {
    enable = true;
    brscan4 = {
      enable = true;
      netDevices."Brother-L2520DW" = {
        model = "DCP-L2520DW";
        ip = "192.168.178.52";
      };
    };
  };

  # Expose scanner over the network so desktop machines can use simple-scan
  services.saned = {
    enable = true;
    extraConfig = "192.168.178.0/24";
  };

  networking.firewall.allowedTCPPorts = [ 6566 ];
}
