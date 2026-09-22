# 3D Modelling and CAD applications
{
  config,
  pkgs,
  lib,
  ...
}:

let
  # Fetched only when this module is imported (orr/yossarian, not milo)
  # TODO: fix fetchGit in pure eval mode — addons temporarily disabled
  # addon = url: builtins.fetchGit { inherit url; ref = "master"; };
in
{
  home.packages = with pkgs; [
    freecad-wayland
    bambu-studio
    openscad
    blender
    printrun
    inkscape
    orca-slicer
  ];

  # FreeCAD addons (symlinked into Mod/ so they're always available)
  # TODO: re-enable once fetchGit pure eval is fixed
  # home.file = {
  #   ".local/share/FreeCAD/Mod/SheetMetal".source = addon "https://github.com/shaise/FreeCAD_SheetMetal";
  #   ".local/share/FreeCAD/Mod/Fasteners".source = addon "https://github.com/shaise/FreeCAD_FastenersWB";
  #   ".local/share/FreeCAD/Mod/Woodworking".source = addon "https://github.com/dprojects/Woodworking";
  #   ".local/share/FreeCAD/Mod/OpenTheme".source = addon "https://github.com/obelisk79/OpenTheme";
  #   ".local/share/FreeCAD/Mod/PartsLibrary".source = addon "https://github.com/FreeCAD/FreeCAD-library";
  # };

}
