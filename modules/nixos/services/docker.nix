# Docker for containerized services
{ config, pkgs, lib, ... }:

{
  virtualisation.docker = {
    enable = true;
    autoPrune = {
      enable = true;
      dates = "weekly";
    };
  };

  # Add weast to docker group
  users.users.weast.extraGroups = [ "docker" ];

  # Useful docker-related packages
  environment.systemPackages = with pkgs; [
    docker-compose
  ];
}
