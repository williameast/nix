# Automated backup jobs
{ config, pkgs, lib, ... }:

{
  # Install rsync
  environment.systemPackages = with pkgs; [ rsync ];

  # Systemd timer for org folder backup (m.2 → Btrfs vault)
  systemd.services.backup-org = {
    description = "Backup org folder to Btrfs vault";
    serviceConfig = {
      Type = "oneshot";
      User = "weast";
      ExecStart = ''
        ${pkgs.rsync}/bin/rsync -av --delete \
          /home/weast/org/ \
          /mnt/vault/org-backup/
      '';
    };
  };

  systemd.timers.backup-org = {
    description = "Backup org folder daily";
    wantedBy = [ "timers.target" ];
    timerConfig = {
      OnCalendar = "daily";
      Persistent = true;  # Run on boot if missed
    };
  };

  # Systemd timer for music backup (Btrfs vault → USB)
  systemd.services.backup-music = {
    description = "Backup music library to USB drive";
    serviceConfig = {
      Type = "oneshot";
      User = "weast";
      ExecStart = ''
        ${pkgs.rsync}/bin/rsync -av --delete \
          /mnt/vault/music/ \
          /mnt/music-backup/
      '';
    };
  };

  systemd.timers.backup-music = {
    description = "Backup music weekly";
    wantedBy = [ "timers.target" ];
    timerConfig = {
      OnCalendar = "weekly";
      Persistent = true;
    };
  };

  # Check backup status with:
  #   systemctl status backup-org.service
  #   systemctl status backup-music.service
  #   journalctl -u backup-org.service
  #   journalctl -u backup-music.service
  #
  # Manual trigger:
  #   sudo systemctl start backup-org.service
  #   sudo systemctl start backup-music.service
}
