# USB drive mounts for media and backups
{ config, pkgs, lib, ... }:

{
  # Create mount points
  systemd.tmpfiles.rules = [
    "d /mnt/media 0755 weast weast -"
    "d /mnt/music-backup 0755 weast weast -"
  ];

  # Mount USB drives by UUID (more reliable than /dev/sdX)
  # Find UUIDs with: lsblk -f
  # Or: ls -l /dev/disk/by-uuid/

  fileSystems."/mnt/media" = {
    # 4TB WD Elements - Films
    device = "/dev/disk/by-uuid/REPLACE-WITH-4TB-UUID";
    fsType = "ext4";  # or "ntfs-3g" if it's NTFS formatted
    options = [ "nofail" "x-systemd.device-timeout=5" ];  # Don't fail boot if unplugged
  };

  fileSystems."/mnt/music-backup" = {
    # 1TB WD Elements - Music Backup
    device = "/dev/disk/by-uuid/REPLACE-WITH-1TB-UUID";
    fsType = "ext4";  # or "ntfs-3g" if it's NTFS formatted
    options = [ "nofail" "x-systemd.device-timeout=5" ];  # Don't fail boot if unplugged
  };

  # Auto-mount USB drives (alternative to static mounts above)
  # Uncomment if you prefer dynamic mounting:
  # services.udisks2.enable = true;
}
