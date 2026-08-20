# 3D Modelling and CAD applications
{
  config,
  pkgs,
  lib,
  inputs,
  ...
}:

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

}
