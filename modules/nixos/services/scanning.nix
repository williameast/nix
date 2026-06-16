# Scanning service for Brother DCP-L2520DW
# - brscan4: SANE backend driver so scanimage/simple-scan can talk to the printer
# - saned: exposes the scanner over the network so desktop machines can scan remotely
# - brscan-skey: listens for scan button presses and saves PDFs to ~/org/scans/
{ config, pkgs, lib, ... }:

let
  scanDir = "/home/weast/org/scans";

  # Script run by brscan-skey when the scan button is pressed
  scanScript = pkgs.writeShellScript "brother-scan-to-org" ''
    set -euo pipefail
    mkdir -p "${scanDir}"
    filename="${scanDir}/scan_$(date +%Y-%m-%d_%H%M%S).pdf"
    ${pkgs.sane-backends}/bin/scanimage \
      --format=pdf \
      --output-file="$filename"
    echo "Saved: $filename"
  '';
in
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
