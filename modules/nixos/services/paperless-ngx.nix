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
      # Receipts are mostly German; with "eng" alone umlauts and words came out garbled.
      # Also selects the tesseract language data the module builds.
      PAPERLESS_OCR_LANGUAGE = "deu+eng";
      # Clean scan noise before OCR (output PDF keeps the original image)
      PAPERLESS_OCR_CLEAN = "clean";
      # Scans from the Brother arrive as 300 dpi JPEG-in-PDF
      PAPERLESS_OCR_IMAGE_DPI = 300;
      # Scanned receipts are often a little crooked or upside down
      PAPERLESS_OCR_DESKEW = true;
      PAPERLESS_OCR_ROTATE_PAGES = true;
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
