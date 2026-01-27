# Desktop modules - GUI applications and desktop environment integration
{ config, pkgs, lib, ... }:

{
  imports = [
    ./firefox.nix
  ];
}
