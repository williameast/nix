# Tailscale VPN
{ config, pkgs, lib, ... }:

{
  services.tailscale.enable = true;

  # Open firewall for Tailscale
  networking.firewall = {
    # Allow Tailscale UDP port
    allowedUDPPorts = [ config.services.tailscale.port ];

    # Allow traffic from Tailscale network
    trustedInterfaces = [ "tailscale0" ];
  };

  # After enabling, run: sudo tailscale up --accept-routes
}
