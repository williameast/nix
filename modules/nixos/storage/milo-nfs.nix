# milo's vault and bulk drives as local folders: /mnt/milo/vault, /mnt/milo/bulk
#
# Mounted on first access and unmounted after 10 idle minutes, so booting
# and suspending never wait for milo. Needs Tailscale up. Server side:
# ../services/nfs-server.nix
#
# Writing into Syncthing receive-only folders (bulk/movies, bulk/tv-shows,
# vault/staging/*) marks them "locally changed" on milo.
{ ... }:

let
  mount = path: {
    device = "milo.quoll-bleak.ts.net:${path}";
    fsType = "nfs";
    options = [
      "nfsvers=4.2"
      "noauto"
      "x-systemd.automount"
      "x-systemd.idle-timeout=600"
      "x-systemd.mount-timeout=15"
      "_netdev"
      "noatime"
      # Give up after ~30 s instead of hanging when milo is unreachable
      "soft"
      "timeo=100"
      "retrans=2"
    ];
  };
in
{
  boot.supportedFilesystems.nfs = true;

  fileSystems."/mnt/milo/vault" = mount "/mnt/vault-new";
  fileSystems."/mnt/milo/bulk" = mount "/mnt/bulk";
}
