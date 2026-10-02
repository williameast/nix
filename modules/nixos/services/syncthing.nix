# Declarative syncthing configuration for NixOS
# Fully managed from syncthing-topology.nix
{ config, pkgs, lib, ... }:

let
  # Import topology - single source of truth
  topology = import ../../home/syncthing-topology.nix { inherit lib; };

  # This machine's hostname
  hostname = config.networking.hostName;

  # User running syncthing
  syncUser = "weast";
  syncGroup = "users";
  homeDir = "/home/${syncUser}";

  # Build syncthing config using topology helper
  syncConfig = topology.buildSyncthingConfig {
    inherit hostname homeDir;
  };

in {
  # Enable syncthing service
  services.syncthing = {
    enable = true;
    user = syncUser;
    group = syncGroup;
    dataDir = homeDir;
    configDir = "${homeDir}/.config/syncthing";

    # Web UI - port 8384 is NOT opened in the firewall, so it's only reachable
    # over Tailscale (tailscale0 is a trusted interface) or localhost
    guiAddress = "0.0.0.0:8384";

    # Declarative configuration
    overrideDevices = true;
    overrideFolders = true;

    settings = {
      inherit (syncConfig) devices folders;
    };
  };

  # Open firewall for syncthing
  networking.firewall = {
    allowedTCPPorts = [ 22000 ];
    allowedUDPPorts = [ 22000 21027 ];
  };

  # Create syncthing folders BEFORE syncthing starts
  # Using activation script for reliability
  system.activationScripts.createSyncthingFolders = lib.stringAfter [ "var" ] ''
    ${lib.concatMapStringsSep "\n" (folder: ''
      mkdir -p "${folder}"
      chown ${syncUser}:${syncGroup} "${folder}"
    '') (lib.mapAttrsToList (_: cfg: cfg.path) syncConfig.folders)}
  '';
}
