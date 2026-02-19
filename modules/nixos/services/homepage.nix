{ config, pkgs, lib, ... }:

{
  services.homepage-dashboard = {
    enable = true;
    listenPort = 8082;
    openFirewall = true;
    allowedHosts = "*";

    settings = {
      title = "milo";
      headerStyle = "clean";
    };

    widgets = [
      { resources = { cpu = true; memory = true; disk = "/"; }; }
      { resources = { disk = "/mnt/vault-new"; }; }
      { search = { provider = "duckduckgo"; target = "_blank"; }; }
    ];

    services = [
      {
        "Media" = [
          { "Jellyfin" = { href = "http://milo:8096"; description = "Media server"; }; }
          { "Navidrome" = { href = "http://milo:4533"; description = "Music server"; }; }
          { "Immich" = { href = "http://milo:2283"; description = "Photo management"; }; }
        ];
      }
      {
        "Infrastructure" = [
          { "Syncthing" = { href = "http://milo:8384"; description = "File sync"; }; }
        ];
      }
    ];
  };
}
