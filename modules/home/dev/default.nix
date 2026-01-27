# Development environment modules
{ config, pkgs, lib, ... }:

{
  imports = [
    ./emacs.nix
    ./direnv.nix
    ./languages.nix
  ];
}
