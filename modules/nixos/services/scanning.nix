# Scanning service for Brother DCP-L2520DW
# Exposes the scanner over the network via saned (SANE daemon)
# Desktop machines connect via SANE net backend and scan with simple-scan
# Scans land in ~/org/scans/ on the desktop and sync everywhere via Syncthing
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

  # Expose scanner over the network
  services.saned = {
    enable = true;
    extraConfig = "192.168.178.0/24";  # allow LAN access
  };

  networking.firewall.allowedTCPPorts = [ 6566 ];
}
