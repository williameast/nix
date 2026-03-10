# Scanning service for Brother DCP-L2520DW
# Uses scanservjs OCI container (nixpkgs package lacks built frontend)
# Web UI at http://milo:8080 — scan, preview, and download from any browser
# Scans also land in ~/org/scans/ and sync to all machines via Syncthing
{ config, pkgs, lib, ... }:

let
  scanOutputDir = "/home/weast/org/scans";
in {
  # Generate brscan4 network device config — volume-mounted into the container
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

  # scanservjs via OCI container — the nixpkgs package is broken (no built frontend)
  virtualisation.podman.enable = true;

  virtualisation.oci-containers = {
    backend = "podman";
    containers.scanservjs = {
      image = "sbs20/scanservjs:release";
      extraOptions = [
        "--network=host"  # reach the Brother scanner on the LAN
      ];
      volumes = [
        "${scanOutputDir}:/app/data/output"
        "/etc/opt/brother/scanner/brscan4:/etc/opt/brother/scanner/brscan4:ro"
      ];
    };
  };

  systemd.tmpfiles.rules = [
    "d ${scanOutputDir} 0775 weast users -"
  ];

  networking.firewall.allowedTCPPorts = [ 8080 ];
}
