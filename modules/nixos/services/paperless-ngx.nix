# Paperless-NGX document management
{ config, pkgs, lib, ... }:

{
  services.paperless = {
    enable = true;
    port = 28981;
    address = "0.0.0.0";
    dataDir = "/mnt/vault-new/paperless";
    consumptionDir = "/mnt/vault-new/paperless/consume";

    settings = {
      PAPERLESS_TIME_ZONE = "Europe/Berlin";
      PAPERLESS_OCR_LANGUAGE = "eng";
    };
  };

  # Ensure directories exist with correct ownership before service starts
  systemd.tmpfiles.rules = [
    "d /mnt/vault-new/paperless 0750 paperless paperless -"
    "d /mnt/vault-new/paperless/consume 0750 paperless paperless -"
  ];

  networking.firewall.allowedTCPPorts = [ 28981 ];

  # After first boot, create your admin account:
  #   sudo -u paperless paperless-ngx manage createsuperuser
  # Then access the web UI at http://milo:28981
}
