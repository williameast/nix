# Syncthing - continuous file synchronization
# Machine-specific folder and device configurations go in hosts/*/default.nix
{ config, pkgs, lib, ... }:

{
  # Enable syncthing service
  services.syncthing = {
    enable = true;

    # Use declarative configuration (folders/devices defined in host configs)
    # This prevents syncthing from modifying its own config
    overrideDevices = true;
    overrideFolders = true;

    # Default settings (can be overridden per-host)
    settings = {
      options = {
        # Start browser UI on startup (localhost:8384)
        urAccepted = -1; # Disable usage reporting
      };
    };
  };

  # Syncthing CLI for debugging
  home.packages = with pkgs; [
    syncthing
  ];
}
