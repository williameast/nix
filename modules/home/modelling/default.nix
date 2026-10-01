# 3D Modelling and CAD applications
{
  config,
  pkgs,
  lib,
  ...
}:

let
  # Fetched lazily — only when this module is imported (orr/yossarian, not milo)
  # To update: run `nix-prefetch-url --unpack <url>/archive/refs/heads/master.tar.gz`
  # then `nix hash to-sri --type sha256 <hash>`
  addon = { owner, repo, hash }: pkgs.fetchFromGitHub {
    inherit owner repo hash;
    rev = "master";
  };
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
  home.file = {
    ".local/share/FreeCAD/Mod/SheetMetal".source = addon {
      owner = "shaise"; repo = "FreeCAD_SheetMetal";
      hash = "sha256-Edb7UVc5yqRzejT2e+uRfVx1Kta0vit/MJJ8MRPdpo4=";
    };
    ".local/share/FreeCAD/Mod/Fasteners".source = addon {
      owner = "shaise"; repo = "FreeCAD_FastenersWB";
      hash = "sha256-1f0E2C4/KfA/wNh2xUYpFMfW6cTcyDMLhPOZ4i/9yU4=";
    };
    ".local/share/FreeCAD/Mod/Woodworking".source = addon {
      owner = "dprojects"; repo = "Woodworking";
      hash = "sha256-5Thrf7AnyXZJfn2nguEmCT+Q0wXNcnKvWzOtwsnIeHI=";
    };
    ".local/share/FreeCAD/Mod/OpenTheme".source = addon {
      owner = "obelisk79"; repo = "OpenTheme";
      hash = "sha256-i5MwrIAncimR+7TRT6L0CQuQqpBWrENdN8v9DGZ0Yo0=";
    };
    ".local/share/FreeCAD/Mod/PartsLibrary".source = addon {
      owner = "FreeCAD"; repo = "FreeCAD-library";
      hash = "sha256-TSpq6A+H3NIfDieuEZ3lWdmKVGabfj04njHqv6CEj+Y=";
    };
  };

}
