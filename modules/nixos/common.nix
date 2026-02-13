# Common NixOS configuration for all servers
{ config, pkgs, lib, ... }:

{
  # Enable flakes
  nix.settings.experimental-features = [ "nix-command" "flakes" ];

  # Allow unfree packages
  nixpkgs.config.allowUnfree = true;

  # Auto-upgrade
  system.autoUpgrade = {
    enable = true;
    allowReboot = false;  # Set to true if you want automatic reboots
  };

  # Automatic garbage collection
  nix.gc = {
    automatic = true;
    dates = "weekly";
    options = "--delete-older-than 30d";
  };

  # Time zone and locale
  time.timeZone = "Europe/Berlin";  # Adjust to your timezone
  i18n.defaultLocale = "en_US.UTF-8";

  # Basic system packages
  environment.systemPackages = with pkgs; [
    git
    vim
    htop
    curl
    wget
    tmux
    smartcl
  ];

  # Enable SSH
  services.openssh = {
    enable = true;
    settings = {
      PermitRootLogin = "prohibit-password";
      PasswordAuthentication = false;
    };
  };

  # Firewall - start with SSH only, services will add their own ports
  networking.firewall = {
    enable = true;
    allowedTCPPorts = [ 22 ];
  };

  # Passwordless sudo for wheel group
  security.sudo.wheelNeedsPassword = false;

  # NOTE: system.stateVersion should be set in each host's configuration.nix
  # It should match the NixOS version at first install (NEVER change it later)
}
