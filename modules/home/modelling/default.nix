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

  # Wrapper for OpenGL apps
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
      { name = "flathub"; location = "https://dl.flathub.org/repo/flathub.flatpakrepo"; }
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
  ];

  # nixGL wrapper for OpenSCAD (needs GPU access)
  home.file = {
    ".local/bin/openscad" = {
      executable = true;
      source = wrapWithGL "openscad" pkgs.openscad;
    };
  };

  # Desktop entry for OpenSCAD with nixGL wrapper
  xdg.desktopEntries = {
    openscad = {
      name = "OpenSCAD";
      exec = "${config.home.homeDirectory}/.local/bin/openscad %f";
      icon = "openscad";
      terminal = false;
      categories = [
        "Graphics"
        "3DGraphics"
        "Engineering"
      ];
      mimeType = [ "application/x-openscad" ];
    };
  };
}
