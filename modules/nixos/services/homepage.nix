{ config, pkgs, lib, ... }:

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
    #
    # Generate keys:
    #   Jellyfin:  Admin Dashboard → API Keys → Add
    #   Navidrome: Settings → Personal → create token (note token + salt)
    #   Immich:    User Settings → API Keys → New API Key
    #   Gitea:     User Settings → Applications → Generate New Token
    environmentFile = "/etc/homepage-secrets.env";

    settings = {

      title = "milo";
      theme = "dark";
      color = "slate";
      headerStyle = "boxedWidgets";
      iconStyle = "theme";
    };

    widgets = [
      { greeting = { text = "Hi William!"; }; }
      { datetime = { locale = "en"; format = { dateStyle = "long"; timeStyle = "short"; }; }; }
      { resources = { cpu = true; memory = true; disk = "/"; label = "System"; }; }
      { resources = { disk = "/mnt/vault-new"; label = "Vault"; }; }
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
              widget = {
                type = "jellyfin";
                url = "http://localhost:8096";
                key = "{{HOMEPAGE_VAR_JELLYFIN_KEY}}";
                enableBlocks = true;
              };
            };
          }
          {
            "Navidrome" = {
              href = "http://milo:4533";
              description = "Music server";
              icon = "navidrome";
            };
          }
          {
            "Immich" = {
              href = "http://milo:2283";
              description = "Photo management";
              icon = "immich";
              widget = {
                type = "immich";
                url = "http://localhost:2283";
                key = "{{HOMEPAGE_VAR_IMMICH_KEY}}";
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
        "Infrastructure" = [
          {
            "Syncthing" = {
              href = "http://milo:8384";
              description = "File sync";
              icon = "syncthing";
            };
          }
        ];
      }
    ];
  };
}
