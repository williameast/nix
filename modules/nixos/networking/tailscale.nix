# Tailscale VPN
{ config, pkgs, lib, ... }:

{
  services.tailscale = {
    enable = true;
    # Let weast run `tailscale up/down` without sudo (Waybar toggle)
    extraSetFlags = [ "--operator=weast" ];
  };

  # Open firewall for Tailscale
  networking.firewall = {
    # Allow Tailscale UDP port
    allowedUDPPorts = [ config.services.tailscale.port ];

    # Allow traffic from Tailscale network
    trustedInterfaces = [ "tailscale0" ];
  };

  # After enabling, run: sudo tailscale up --accept-routes
}
