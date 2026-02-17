# Immich photo management server
{ config, pkgs, lib, ... }:

{
  services.immich = {
    enable = true;
    host = "0.0.0.0";
    port = 2283;
    mediaLocation = "/mnt/vault-new/immich";
    openFirewall = true;
  };
}
