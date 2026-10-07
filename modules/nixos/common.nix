# Common NixOS configuration for all hosts
{ config, pkgs, lib, ... }:

{
  # Enable flakes
  nix.settings.experimental-features = [ "nix-command" "flakes" ];

  # Allow unfree packages
  nixpkgs.config.allowUnfree = true;

  # Auto-upgrade disabled - managed manually via the rebuild alias
  # system.autoUpgrade.enable = true;

  # Automatic garbage collection
  nix.gc = {
    automatic = true;
    dates = "weekly";
    options = "--delete-older-than 30d";
  };

  # Time zone and locale
  # mkDefault so hosts can override (e.g. yossarian)
  time.timeZone = lib.mkDefault "Europe/Berlin";
  i18n.defaultLocale = lib.mkDefault "en_US.UTF-8";

  # Basic system packages
  environment.systemPackages = with pkgs; [
    git
    vim
    htop
    curl
    wget
    tmux
    usbutils  # lsusb

    # Drop into a shell as a service user with its full environment:
    #   sudo svc-shell paperless-web
    #   sudo svc-shell immich-server
    # Then run whatever management commands the service provides.
    (writeShellScriptBin "svc-shell" ''
      set -euo pipefail
      if [ $# -lt 1 ]; then
        echo "Usage: svc-shell <unit-name> [command ...]" >&2
        echo "Drops you into a shell with the service's environment." >&2
        echo "Examples:" >&2
        echo "  sudo svc-shell paperless-web" >&2
        echo "  sudo svc-shell paperless-web manage.py changepassword admin" >&2
        exit 1
      fi

      unit="$1"; shift
      if ! systemctl cat "$unit.service" &>/dev/null; then
        echo "Service $unit.service not found" >&2
        exit 1
      fi

      svc_user=$(systemctl show "$unit.service" -p User --value)
      svc_user="''${svc_user:-root}"

      # Collect environment from the service unit
      env_args=()
      while IFS= read -r var; do
        [ -n "$var" ] && env_args+=(--setenv "$var")
      done < <(systemctl show "$unit.service" -p Environment --value | tr ' ' '\n')

      svc_path=$(systemctl show "$unit.service" -p ExecSearchPath --value 2>/dev/null || true)

      if [ $# -gt 0 ]; then
        exec systemd-run --pipe --quiet --uid="$svc_user" "''${env_args[@]}" -- ${bash}/bin/bash -lc "$*"
      else
        exec systemd-run --pipe --quiet --uid="$svc_user" "''${env_args[@]}" -- ${bash}/bin/bash
      fi
    '')
  ];

  # Zsh as login shell
  programs.zsh.enable = true;

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
