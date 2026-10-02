# Automated backup jobs with database dumps and ntfy notifications
{ config, pkgs, lib, ... }:

let
  ntfyBase = "http://localhost:2586";
  ntfyNotify = topic: msg: "${pkgs.curl}/bin/curl -s -d '${msg}' ${ntfyBase}/${topic}";

  # Services to monitor for failures (long-running daemons)
  monitoredServices = [
    "jellyfin"
    "navidrome"
    "immich"
    "syncthing"
    "homepage-dashboard"
    "gitea"
    "paperless-web"
    "paperless-scheduler"
    "paperless-consumer"
    "paperless-task-queue"
    "ntfy-sh"
    "buero"
    "tailscaled"
  ];
in
{
  environment.systemPackages = with pkgs; [
    rsync
    sqlite
    curl
  ];

  systemd.services =
    # --- Service monitoring ---
    # Attach OnFailure to all long-running services so we get notified if they crash
    lib.genAttrs monitoredServices (name: {
      unitConfig.OnFailure = [ "ntfy-failure@%N.service" ];
    })
    // {
      # --- Failure notification template unit ---
      # Any service with OnFailure = [ "ntfy-failure@%N.service" ] will trigger this
      "ntfy-failure@" = {
        description = "Send ntfy failure notification for %I";
        serviceConfig = {
          Type = "oneshot";
          ExecStart = ''
            ${pkgs.curl}/bin/curl -s -H "Priority: high" -H "Tags: warning" -d "FAILED: %I" ${ntfyBase}/alerts
          '';
        };
      };

      # --- Database dump services (run before main backup window) ---

      # Paperless SQLite backup
      backup-dump-paperless = {
        description = "Dump Paperless SQLite database and media";
        serviceConfig = {
          Type = "oneshot";
          User = "root";
          ExecStart = pkgs.writeShellScript "backup-dump-paperless" ''
            set -euo pipefail
            mkdir -p /mnt/vault-new/backups/paperless
            # Backup SQLite database
            ${pkgs.sqlite}/bin/sqlite3 /mnt/vault-new/paperless/db.sqlite3 \
              ".backup '/mnt/vault-new/backups/paperless/db.sqlite3'"
            # Backup media directory
            ${pkgs.rsync}/bin/rsync -a --delete \
              /mnt/vault-new/paperless/media/ \
              /mnt/vault-new/backups/paperless/media/
          '';
          ExecStartPost = ntfyNotify "backups" "Paperless DB dump completed";
        };
        unitConfig.OnFailure = [ "ntfy-failure@%N.service" ];
      };

      # Immich PostgreSQL backup
      backup-dump-immich = {
        description = "Dump Immich PostgreSQL database";
        serviceConfig = {
          Type = "oneshot";
          User = "immich";
          ExecStartPre = "${pkgs.coreutils}/bin/mkdir -p /mnt/vault-new/backups/immich";
          ExecStart = ''
            ${config.services.postgresql.package}/bin/pg_dump -Fc -f /mnt/vault-new/backups/immich/immich.pgdump immich
          '';
          ExecStartPost = ntfyNotify "backups" "Immich DB dump completed";
        };
        unitConfig.OnFailure = [ "ntfy-failure@%N.service" ];
      };

      # Immich full backup to bulk HDD (DB dump + media)
      # Runs after the DB dump so the pgdump file is fresh
      backup-immich = {
        description = "Backup Immich DB dump and media to bulk drive";
        after = [ "backup-dump-immich.service" ];
        requires = [ "backup-dump-immich.service" ];
        serviceConfig = {
          Type = "oneshot";
          ExecStart = pkgs.writeShellScript "backup-immich" ''
            set -euo pipefail
            mkdir -p /mnt/bulk/backups/immich
            # Backup DB dump
            ${pkgs.rsync}/bin/rsync -av --delete \
              /mnt/vault-new/backups/immich/ \
              /mnt/bulk/backups/immich/db/
            # Backup media (photos/videos)
            ${pkgs.rsync}/bin/rsync -av --delete \
              /mnt/vault-new/immich/ \
              /mnt/bulk/backups/immich/media/
          '';
          ExecStartPost = ntfyNotify "backups" "Immich backup to bulk completed";
        };
        unitConfig.OnFailure = [ "ntfy-failure@%N.service" ];
      };

      # --- Existing backup services (now with ntfy) ---

      # Org folder backup (m.2 → Btrfs vault)
      backup-org = {
        description = "Backup org folder to Btrfs vault";
        serviceConfig = {
          Type = "oneshot";
          User = "weast";
          ExecStart = ''
            ${pkgs.rsync}/bin/rsync -av --delete \
              /home/weast/org/ \
              /mnt/vault/org-backup/
          '';
          ExecStartPost = ntfyNotify "backups" "Org backup completed";
        };
        unitConfig.OnFailure = [ "ntfy-failure@%N.service" ];
      };

      # Music backup (Btrfs vault → bulk HDD)
      backup-music = {
        description = "Backup music library to bulk drive";
        serviceConfig = {
          Type = "oneshot";
          User = "weast";
          ExecStartPre = "${pkgs.coreutils}/bin/mkdir -p /mnt/bulk/backups/music";
          ExecStart = ''
            ${pkgs.rsync}/bin/rsync -av --delete \
              /mnt/vault/music/ \
              /mnt/bulk/backups/music/
          '';
          ExecStartPost = ntfyNotify "backups" "Music backup completed";
        };
        unitConfig.OnFailure = [ "ntfy-failure@%N.service" ];
      };
    };

  systemd.timers = {
    backup-dump-paperless = {
      description = "Dump Paperless database daily";
      wantedBy = [ "timers.target" ];
      timerConfig = {
        OnCalendar = "*-*-* 02:15:00";
        Persistent = true;
      };
    };

    backup-dump-immich = {
      description = "Dump Immich database daily";
      wantedBy = [ "timers.target" ];
      timerConfig = {
        OnCalendar = "*-*-* 02:30:00";
        Persistent = true;
      };
    };

    backup-immich = {
      description = "Backup Immich to bulk drive weekly";
      wantedBy = [ "timers.target" ];
      timerConfig = {
        OnCalendar = "weekly";
        Persistent = true;
      };
    };

    backup-org = {
      description = "Backup org folder daily";
      wantedBy = [ "timers.target" ];
      timerConfig = {
        OnCalendar = "daily";
        Persistent = true;
      };
    };

    backup-music = {
      description = "Backup music weekly";
      wantedBy = [ "timers.target" ];
      timerConfig = {
        OnCalendar = "weekly";
        Persistent = true;
      };
    };
  };

  # Ensure backup directories exist
  systemd.tmpfiles.rules = [
    "d /mnt/vault-new/backups 0755 root root -"
    "d /mnt/vault-new/backups/paperless 0750 root root -"
    "d /mnt/vault-new/backups/immich 0750 immich immich -"
  ];

  # Check backup status with:
  #   systemctl list-timers 'backup-*'
  #   journalctl -u backup-org.service
  #   journalctl -u backup-dump-paperless.service
  #
  # Manual trigger:
  #   sudo systemctl start backup-org.service
  #   sudo systemctl start backup-dump-paperless.service
}
