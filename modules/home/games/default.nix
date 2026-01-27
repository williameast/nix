# Games - Steam and gaming utilities
{ config, pkgs, lib, inputs, ... }:

let
  nixgl = inputs.nixgl.packages.${pkgs.system};
in {
  home.packages = with pkgs; [
    steam
  ];

  # Steam needs nixGL wrapper for GPU access on non-NixOS
  home.file.".local/bin/steam" = {
    executable = true;
    source = pkgs.writeShellScript "steam-nixgl" ''
      exec ${nixgl.nixGLIntel}/bin/nixGLIntel ${pkgs.steam}/bin/steam "$@"
    '';
  };

  # Desktop entry for Steam with nixGL
  xdg.desktopEntries.steam = {
    name = "Steam";
    exec = "${config.home.homeDirectory}/.local/bin/steam %U";
    icon = "steam";
    terminal = false;
    categories = [ "Game" "Network" ];
    mimeType = [ "x-scheme-handler/steam" ];
    settings = {
      StartupWMClass = "steam";
    };
  };
}
