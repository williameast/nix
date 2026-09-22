# 3D Modelling and CAD applications
{
  config,
  pkgs,
  lib,
  inputs,
  ...
}:

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
  home.file = {
    ".local/share/FreeCAD/Mod/SheetMetal".source = inputs.freecad-sheetmetal;
    ".local/share/FreeCAD/Mod/Fasteners".source = inputs.freecad-fasteners;
    ".local/share/FreeCAD/Mod/Woodworking".source = inputs.freecad-woodworking;
    ".local/share/FreeCAD/Mod/OpenTheme".source = inputs.freecad-opentheme;
    ".local/share/FreeCAD/Mod/PartsLibrary".source = inputs.freecad-parts-library;
  };

}
