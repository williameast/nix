# User configuration
{ config, pkgs, lib, ... }:

{
  users.users.weast = {
    isNormalUser = true;
    extraGroups = [ "wheel" ];  # wheel = sudo access
    openssh.authorizedKeys.keys = [
      "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABgQDd1LC+eldUgjQhCey2ahNuKY8cTvLiOhA/jO743AIspONHBMyJhQ510QUYdASd7kjpEyyXE11PVbZLFN9alcUhiPNEcZY0HZlThGyr+pH0aqnRcuQm9n2xTUX18Md0y76A/D1fa9arRAHx5v59g1UDiJEEXWc/e3kPUoBNgYSLGs0Q/fnOHFoCU4pMhLcDD1vnhtO8/UfjHWe8oMYBAkh5rZ2ORRz2m58bFd+7eJGpX3XOwT9bQ6EmpBvXklxTs349ItdyZ/Q5OngbWxJRt9sHCl5dVHpjY2YgxtIScxHdJHuiCIkhTgKeRkb5hVWQiLNR89ZPKJGqVgTqNVT7fs0ZA0N/I4agIdROWYVPYSBO3G5Ewp7z/OqE8+hEkcm2TyN+R4RCLnsMaD02ahb4bGxzD5ILKg79P9NuNrGJoxTr14N9Q6rwuL+xYw/LTCyL1tqU8erd34pBg6AoCPW6dueMam3ig4IgCVZ8VYl8kiAnZsZZKv2CyuvPFNxoyW2LJ98= weast@yossarian"
    ];
  };
}
