# 3D Modelling and CAD applications
{ config, pkgs, lib, inputs, ... }:

let
  nixgl = inputs.nixgl.packages.${pkgs.system};

  # Wrapper for OpenGL apps
  wrapWithGL = name: pkg: pkgs.writeShellScript "${name}-nixgl" ''
    exec ${nixgl.nixGLIntel}/bin/nixGLIntel ${pkg}/bin/${name} "$@"
  '';
in {
  home.packages = with pkgs; [
    # freecad  # TODO: broken in nixpkgs (openturns dependency fails to build)
    openscad
    bambu-studio
  ];

  # nixGL wrappers for 3D apps (they need GPU access)
  home.file = {
    # ".local/bin/freecad" = {
    #   executable = true;
    #   source = wrapWithGL "FreeCAD" pkgs.freecad;
    # };
    ".local/bin/openscad" = {
      executable = true;
      source = wrapWithGL "openscad" pkgs.openscad;
    };
    ".local/bin/bambu-studio" = {
      executable = true;
      source = wrapWithGL "bambu-studio" pkgs.bambu-studio;
    };
  };

  # Desktop entries with nixGL wrappers
  xdg.desktopEntries = {
    # freecad = {
    #   name = "FreeCAD";
    #   exec = "${config.home.homeDirectory}/.local/bin/freecad %F";
    #   icon = "freecad";
    #   terminal = false;
    #   categories = [ "Graphics" "Science" "Engineering" ];
    #   mimeType = [ "application/x-extension-fcstd" ];
    # };
    openscad = {
      name = "OpenSCAD";
      exec = "${config.home.homeDirectory}/.local/bin/openscad %f";
      icon = "openscad";
      terminal = false;
      categories = [ "Graphics" "3DGraphics" "Engineering" ];
      mimeType = [ "application/x-openscad" ];
    };
    bambu-studio = {
      name = "Bambu Studio";
      exec = "${config.home.homeDirectory}/.local/bin/bambu-studio %F";
      icon = "bambu-studio";
      terminal = false;
      categories = [ "Graphics" "3DGraphics" "Engineering" ];
    };
  };
}
