# Atuin sync server - shell history synced between orr, yossarian and milo
# (Tailscale-only: no firewall port opened, tailscale0 is trusted)
{ config, pkgs, lib, ... }:

{
  services.atuin = {
    enable = true;
    host = "0.0.0.0";
    port = 8888;
    # Registration open so each machine can `atuin register`; once your
    # account exists, set to false and rebuild milo (`atuin login` still works).
    openRegistration = true;
  };
}
