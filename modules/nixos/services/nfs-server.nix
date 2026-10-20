# NFS - milo's drives as network folders on orr and yossarian
#
# Exports vault and bulk over the tailnet only (tailscale0 is a trusted
# interface, the LAN firewall stays closed). NFSv4 only: one port, no rpcbind.
# Access works like SSH as weast: same uid on all machines, files of other
# services (immich, gitea, …) stay off limits, and root on a client is
# squashed to nobody. Clients: ../storage/milo-nfs.nix
{ lib, ... }:

let
  # Tailscale addresses (`tailscale status`)
  clients = {
    orr = "100.72.43.120";
    yossarian = "100.100.196.16";
  };
  opts = "rw,sync,no_subtree_check";
  export = path: "${path} " + lib.concatMapStringsSep " " (ip: "${ip}(${opts})") (lib.attrValues clients);
in
{
  services.nfs = {
    server = {
      enable = true;
      exports = ''
        ${export "/mnt/vault-new"}
        ${export "/mnt/bulk"}
      '';
    };
    settings.nfsd = {
      vers3 = false;
      "vers4.0" = false;
    };
  };

  systemd.services.nfs-server.unitConfig.RequiresMountsFor = [ "/mnt/vault-new" ];
}
