# Scanning service for Brother DCP-L2520DW
# Uses scanservjs (web UI) + SANE brscan4 driver
# Scans are saved to ~/org/scans/ → synced to all machines via Syncthing
# Web UI accessible at http://milo:8080
{ config, pkgs, lib, ... }:

{
  hardware.sane.brscan4 = {
    enable = true;
    netDevices = {
      "Brother-L2520DW" = {
        model = "DCP-L2520DW";
        ip = "192.168.178.39";
      };
    };
  };

  services.scanservjs = {
    enable = true;
    settings = {
      host = "0.0.0.0";
      outputDirectory = "/home/weast/org/scans";
    };
  };

  # Output dir owned by weast:scanner (scanservjs user is in scanner group)
  systemd.tmpfiles.rules = [
    "d /home/weast/org/scans 0775 weast scanner -"
  ];

  networking.firewall.allowedTCPPorts = [ 8080 ];
}
