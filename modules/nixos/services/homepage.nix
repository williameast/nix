{ config, pkgs, lib, ... }:

let
  # Ollama on orr, queried directly — NOT through milo:11434, whose proxy
  # would wake orr on every dashboard refresh. Unreachable = orr asleep.
  orrOllama = "http://orr.quoll-bleak.ts.net:11434";
in
{
  # Ensure secrets env file exists (empty is fine — widgets just won't auth)
  # To populate, edit /etc/homepage-secrets.env with real API keys
  systemd.tmpfiles.rules = [
    "f /etc/homepage-secrets.env 0600 root root -"
  ];

  services.homepage-dashboard = {
    enable = true;
    listenPort = 8082;
    openFirewall = true;
    allowedHosts = "*";

    # API keys for service widgets — source from env file
    # Create /etc/homepage-secrets.env with:
    #   HOMEPAGE_VAR_JELLYFIN_KEY=<your-jellyfin-api-key>
    #   HOMEPAGE_VAR_NAVIDROME_TOKEN=<your-navidrome-token>
    #   HOMEPAGE_VAR_NAVIDROME_SALT=<your-navidrome-salt>
    #   HOMEPAGE_VAR_IMMICH_KEY=<your-immich-api-key>
    #   HOMEPAGE_VAR_GITEA_KEY=<your-gitea-api-token>
    #   HOMEPAGE_VAR_PAPERLESS_KEY=<your-paperless-api-token>
    #   HOMEPAGE_VAR_SYNCTHING_KEY=<syncthing-gui-api-key>
    #
    # Generate keys:
    #   Jellyfin:  Admin Dashboard → API Keys → Add
    #   Navidrome: Settings → Personal → create token (note token + salt)
    #   Immich:    User Settings → API Keys → New API Key
    #   Gitea:     User Settings → Applications → Generate New Token
    #   Paperless: sudo paperless-manage drf_create_token weast
    #   Syncthing: <apikey> in ~/.config/syncthing/config.xml
    environmentFiles = [ "/etc/homepage-secrets.env" ];

    settings = {

      title = "milo";
      theme = "dark";
      color = "slate";
      headerStyle = "boxedWidgets";
      iconStyle = "theme";
      # Status dots (siteMonitor) show response time on hover
      statusStyle = "dot";
    };

    widgets = [
      { greeting = { text = "Hi William!"; }; }
      { datetime = { locale = "en"; format = { dateStyle = "long"; timeStyle = "short"; }; }; }
      { resources = { cpu = true; memory = true; cputemp = true; uptime = true; label = "System"; }; }
      { resources = { disk = "/"; label = "Root"; }; }
      { resources = { disk = "/mnt/vault-new"; label = "Vault"; }; }
      { resources = { disk = "/mnt/bulk"; label = "Bulk"; }; }
      { search = { provider = "duckduckgo"; target = "_blank"; }; }
    ];

    services = [
      {
        "Media" = [
          {
            "Jellyfin" = {
              href = "http://milo:8096";
              description = "Media server";
              icon = "jellyfin";
              siteMonitor = "http://localhost:8096";
              widget = {
                type = "jellyfin";
                url = "http://localhost:8096";
                key = "{{HOMEPAGE_VAR_JELLYFIN_KEY}}";
                # Jellyfin 10.11+ dropped the /emby API that version 1 calls
                version = 2;
                enableBlocks = true;
                enableNowPlaying = true;
              };
            };
          }
          {
            "Navidrome" = {
              href = "http://milo:4533";
              description = "Music server";
              icon = "navidrome";
              siteMonitor = "http://localhost:4533";
            };
          }
          {
            "Immich" = {
              href = "http://milo:2283";
              description = "Photo management";
              icon = "immich";
              siteMonitor = "http://localhost:2283";
              widget = {
                type = "immich";
                url = "http://localhost:2283";
                key = "{{HOMEPAGE_VAR_IMMICH_KEY}}";
                # Immich v1.118+ API
                version = 2;
              };
            };
          }
        ];
      }
      {
        "AI" = [
          {
            "Ollama (orr)" = {
              href = "http://milo:11434";
              description = "Local LLMs on orr's GPU; offline = orr asleep, wakes on request";
              icon = "ollama";
              siteMonitor = orrOllama;
              widget = {
                type = "customapi";
                url = "${orrOllama}/api/ps";
                refreshInterval = 60000;
                mappings = [
                  { field = "models"; label = "Loaded"; format = "size"; }
                  { field = "models.0.name"; label = "Model"; }
                  { field = "models.0.size_vram"; label = "VRAM"; format = "bytes"; }
                ];
              };
            };
          }
        ];
      }
      {
        "Development" = [
          {
            "Gitea" = {
              href = "http://milo:3000";
              description = "Git hosting";
              icon = "gitea";
              siteMonitor = "http://localhost:3000";
              widget = {
                type = "gitea";
                url = "http://localhost:3000";
                key = "{{HOMEPAGE_VAR_GITEA_KEY}}";
              };
            };
          }
        ];
      }
      {
        "Productivity" = [
          {
            "Paperless" = {
              href = "http://milo:28981";
              description = "Document management";
              icon = "paperless-ngx";
              siteMonitor = "http://localhost:28981";
              widget = {
                type = "paperlessngx";
                url = "http://localhost:28981";
                key = "{{HOMEPAGE_VAR_PAPERLESS_KEY}}";
              };
            };
          }
          {
            "Büro" = {
              href = "http://milo:5055";
              description = "Invoices, clients, bank";
              icon = "mdi-briefcase-outline";
              siteMonitor = "http://localhost:5055";
            };
          }
        ];
      }
      {
        "Infrastructure" = [
          {
            "Syncthing" = {
              href = "http://milo:8384";
              description = "File sync";
              icon = "syncthing";
              siteMonitor = "http://localhost:8384";
              widget = {
                type = "syncthing";
                url = "http://localhost:8384";
                key = "{{HOMEPAGE_VAR_SYNCTHING_KEY}}";
              };
            };
          }
          {
            "FileBrowser" = {
              href = "https://milo.quoll-bleak.ts.net:8443";
              description = "Share files via public links";
              icon = "filebrowser";
            };
          }
          {
            "ntfy" = {
              href = "http://milo:2586";
              description = "Push notifications";
              icon = "ntfy";
              siteMonitor = "http://localhost:2586";
            };
          }
          { "Scanner" = { description = "Brother DCP-L2520DW — use simple-scan on desktop"; }; }
        ];
      }
    ];
  };
}
