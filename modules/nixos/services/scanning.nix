# Scanning service for Brother DCP-L2520DW
# - brscan4: SANE backend driver so scanimage/simple-scan can talk to the printer
# - saned: exposes the scanner over the network so desktop machines can scan remotely
#
# Note: brscan-skey (scan button handler) is not packaged in nixpkgs.
# On a headless server it's not useful anyway — desktops connect via saned.
{ config, pkgs, lib, ... }:
{
  hardware.sane = {
    enable = true;
    brscan4 = {
      enable = true;
      netDevices."Brother-L2520DW" = {
        model = "DCP-L2520DW";
        ip = "192.168.178.39";
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
