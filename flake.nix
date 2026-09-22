{
  description = "weast's Home Manager configuration";

  inputs = {
    # Core inputs
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";

    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # nixGL for OpenGL on non-NixOS (required for Firefox WebGL on Pop!_OS)
    nixgl = {
      url = "github:nix-community/nixGL";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # NUR for Firefox extensions
    nur.url = "github:nix-community/NUR";

# Claude Code CLI
    claude-code = {
      url = "github:sadjow/claude-code-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # Claude Desktop (Linux) — pinned to last working build before 1.8089.1 tray patch broke
    claude-desktop.url = "github:aaddrick/claude-desktop-debian/ba2846c8b3e9";

    # Affinity suite for Linux
    affinity-nix.url = "github:mrshmllow/affinity-nix";

    # FreeCAD addons (symlinked into ~/.local/share/FreeCAD/Mod/)
    freecad-sheetmetal = { url = "github:shaise/FreeCAD_SheetMetal"; flake = false; };
    freecad-fasteners = { url = "github:shaise/FreeCAD_FastenersWB"; flake = false; };
    freecad-woodworking = { url = "github:dprojects/Woodworking"; flake = false; };
    freecad-opentheme = { url = "github:obelisk79/OpenTheme"; flake = false; };
    # Parts Library (several GB)
    freecad-parts-library = { url = "github:FreeCAD/FreeCAD-library"; flake = false; };
  };

  outputs = { self, nixpkgs, home-manager, nixgl, nur, ... }@inputs:
    let
      system = "x86_64-linux";
      pkgs = import nixpkgs {
        inherit system;
        config.allowUnfree = true;
      };
      mkHost = hostConfig: nixpkgs.lib.nixosSystem {
        specialArgs = { inherit inputs; };
        modules = [
          { nixpkgs.hostPlatform.system = system; }
          hostConfig
        ];
      };
    in {
      # NixOS system configurations
      # Note: All hosts use home-manager as a NixOS module (config in hosts/*/home.nix)
      nixosConfigurations.orr = mkHost ./hosts/orr/configuration.nix;
      nixosConfigurations.yossarian = mkHost ./hosts/yossarian/configuration.nix;
      nixosConfigurations.milo = mkHost ./hosts/milo/configuration.nix;
    };
}
