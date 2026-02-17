# mDNS/DNS-SD via Avahi - makes this host discoverable as <hostname>.local
{ config, ... }:

{
  services.avahi = {
    enable = true;
    nssmdns4 = true;
    publish = {
      enable = true;
      addresses = true;
    };
  };

  # Avahi uses UDP 5353 for mDNS
  networking.firewall.allowedUDPPorts = [ 5353 ];
}
