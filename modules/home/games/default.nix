# Games - Steam and gaming utilities
{ config, pkgs, lib, inputs, ... }:

let
  nixgl = inputs.nixgl.packages.${pkgs.system};
  # Detect if we're on NixOS (where nixGL wrapper is not needed)
  isNixOS = config.targets.genericLinux.enable == false;
in {
  home.packages = with pkgs; [
    steam
  ];

  # Steam needs nixGL wrapper for GPU access on non-NixOS only
  home.file.".local/bin/steam" = lib.mkIf (!isNixOS) {
    executable = true;
    source = pkgs.writeShellScript "steam-nixgl" ''
      exec ${nixgl.nixGLIntel}/bin/nixGLIntel ${pkgs.steam}/bin/steam "$@"
    '';
  };

  # Desktop entry for Steam - uses nixGL wrapper on non-NixOS, native on NixOS
  xdg.desktopEntries.steam = {
    name = "Steam";
    exec = if isNixOS
      then "${pkgs.steam}/bin/steam %U"
      else "${config.home.homeDirectory}/.local/bin/steam %U";
    icon = "steam";
    terminal = false;
    categories = [ "Game" "Network" ];
    mimeType = [ "x-scheme-handler/steam" ];
    settings = {
      StartupWMClass = "steam";
    };
  };
}
