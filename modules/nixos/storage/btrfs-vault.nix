# Btrfs RAID1 pool for critical data (music, backups, archives)
# RAID1: 1TB SATA SSD + 2TB Samsung HDD (1TB usable)
{ config, pkgs, lib, ... }:

{
  # Enable Btrfs support (native in kernel)
  boot.supportedFilesystems = [ "btrfs" ];

  # Install Btrfs tools
  environment.systemPackages = with pkgs; [
    btrfs-progs
    compsize  # Check compression stats
  ];

  # Automatic Btrfs scrub (data integrity check)
  services.btrfs.autoScrub = {
    enable = true;
    fileSystems = [ "/mnt/vault" ];
    interval = "weekly";
  };

  # Automatic snapshots with snapper
  services.snapper = {
    configs = {
      vault = {
        SUBVOLUME = "/mnt/vault";
        ALLOW_USERS = [ "weast" ];
        TIMELINE_CREATE = true;
        TIMELINE_CLEANUP = true;
        # Snapshot retention
        TIMELINE_MIN_AGE = "1800";  # Keep snapshots for at least 30 minutes
        TIMELINE_LIMIT_HOURLY = "24";
        TIMELINE_LIMIT_DAILY = "7";
        TIMELINE_LIMIT_WEEKLY = "4";
        TIMELINE_LIMIT_MONTHLY = "12";
        TIMELINE_LIMIT_YEARLY = "0";
      };
    };
  };

  # Mount point will be created automatically
  # After creating the filesystem with:
  #   sudo mkfs.btrfs -L vault -d raid1 -m raid1 \
  #     /dev/disk/by-id/YOUR-1TB-SSD-ID \
  #     /dev/disk/by-id/YOUR-2TB-HDD-ID
  #
  #   sudo mount /dev/disk/by-label/vault /mnt/vault
  #   sudo btrfs subvolume create /mnt/vault/music
  #   sudo btrfs subvolume create /mnt/vault/org-backup
  #   sudo btrfs subvolume create /mnt/vault/archive
  #   sudo chown -R weast:weast /mnt/vault
  #   sudo umount /mnt/vault
  #
  # Then add to /etc/nixos/configuration.nix or create mount config:
  #   fileSystems."/mnt/vault" = {
  #     device = "/dev/disk/by-label/vault";
  #     fsType = "btrfs";
  #     options = [ "compress=zstd" "noatime" ];
  #   };

  # Ensure mount point exists
  systemd.tmpfiles.rules = [
    "d /mnt/vault 0755 root root -"
  ];

  # Mount vault filesystem
  fileSystems."/mnt/vault" = {
    device = "/dev/disk/by-label/vault";
    fsType = "btrfs";
    options = [
      "compress=zstd"  # Automatic compression (better than lz4)
      "noatime"        # Don't update access times (faster)
    ];
  };
}
