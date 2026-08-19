# 3D Modelling and CAD applications
{
  config,
  pkgs,
  lib,
  inputs,
  ...
}:

let
  nixgl = inputs.nixgl.packages.${pkgs.system};
  # Detect if we're on NixOS (where nixGL wrapper is not needed)
  isNixOS = config.targets.genericLinux.enable == false;

  # Wrapper for OpenGL apps (only needed on non-NixOS)
  wrapWithGL =
    name: pkg:
    pkgs.writeShellScript "${name}-nixgl" ''
      exec ${nixgl.nixGLIntel}/bin/nixGLIntel ${pkg}/bin/${name} "$@"
    '';
in
{
  imports = [
    inputs.nix-flatpak.homeManagerModules.nix-flatpak
  ];

  # Flatpak configuration
  services.flatpak = {
    enable = true;
    remotes = [
      {
        name = "flathub";
        location = "https://dl.flathub.org/repo/flathub.flatpakrepo";
      }
    ];
    packages = [
      "org.freecadweb.FreeCAD"
      "com.bambulab.BambuStudio"
    ];
    update.auto = {
      enable = true;
      onCalendar = "weekly";
    };
  };

  # Nix packages (OpenSCAD still works from nixpkgs)
  home.packages = with pkgs; [
    openscad
    blender
    printrun
    inkscape
  ];

  # nixGL wrappers for GPU-accelerated apps (non-NixOS only)
  home.file = lib.mkIf (!isNixOS) {
    ".local/bin/openscad" = {
      executable = true;
      source = wrapWithGL "openscad" pkgs.openscad;
    };
    ".local/bin/blender" = {
      executable = true;
      source = wrapWithGL "blender" pkgs.blender;
    };
  };

  # Desktop entries - use nixGL wrapper on non-NixOS, native binary on NixOS
  xdg.desktopEntries = {
    openscad = {
      name = "OpenSCAD";
      exec = if isNixOS
        then "${pkgs.openscad}/bin/openscad %f"
        else "${config.home.homeDirectory}/.local/bin/openscad %f";
      icon = "openscad";
      terminal = false;
      categories = [
        "Graphics"
        "3DGraphics"
        "Engineering"
      ];
      mimeType = [ "application/x-openscad" ];
    };
    blender = {
      name = "Blender";
      exec = if isNixOS
        then "${pkgs.blender}/bin/blender %f"
        else "${config.home.homeDirectory}/.local/bin/blender %f";
      icon = "blender";
      terminal = false;
      categories = [
        "Graphics"
        "3DGraphics"
      ];
      mimeType = [ "application/x-blender" ];
    };
  };
}
