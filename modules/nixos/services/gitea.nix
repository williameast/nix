# Gitea - lightweight self-hosted git service
{ config, pkgs, lib, ... }:

{
  services.gitea = {
    enable = true;

    settings = {
      server = {
        HTTP_PORT = 3000;
        HTTP_ADDR = "0.0.0.0";
        ROOT_URL = "http://milo:3000";
      };
      service = {
        DISABLE_REGISTRATION = false;
      };
    };

    # Store data on RAID1 vault
    stateDir = "/mnt/vault-new/gitea";

    # SQLite is the default — simple and sufficient for personal use
    database.type = "sqlite3";
  };

  # Ensure state directory exists with correct ownership
  systemd.tmpfiles.rules = [
    "d /mnt/vault-new/gitea 0750 gitea gitea -"
  ];

  networking.firewall.allowedTCPPorts = [ 3000 ];

  # After first boot, create your admin account:
  #   sudo -u gitea gitea admin user create --admin \
  #     --username weast --email you@example.com --password <password>
  # Registration is disabled, so all users must be created via CLI.
}
