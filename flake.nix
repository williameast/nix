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

    # Declarative Flatpak management
    nix-flatpak.url = "github:gmodena/nix-flatpak";

    # Claude Code CLI
    claude-code = {
      url = "github:sadjow/claude-code-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # Claude Desktop (Linux) — pinned to last working build before 1.8089.1 tray patch broke
    claude-desktop.url = "github:aaddrick/claude-desktop-debian/ba2846c8b3e9";
  };

  outputs = { self, nixpkgs, home-manager, nixgl, nur, ... }@inputs:
    let
      system = "x86_64-linux";
      pkgs = import nixpkgs {
        inherit system;
        config.allowUnfree = true;
      };
    in {
      # NixOS system configurations
      # Note: All hosts use home-manager as a NixOS module (config in hosts/*/home.nix)
      nixosConfigurations.orr = nixpkgs.lib.nixosSystem {
        inherit system;

        specialArgs = { inherit inputs; };

        modules = [
          ./hosts/orr/configuration.nix
        ];
      };

      nixosConfigurations.yossarian = nixpkgs.lib.nixosSystem {
        inherit system;

        specialArgs = { inherit inputs; };

        modules = [
          ./hosts/yossarian/configuration.nix
        ];
      };

      nixosConfigurations.milo = nixpkgs.lib.nixosSystem {
        inherit system;

        specialArgs = { inherit inputs; };

        modules = [
          ./hosts/milo/configuration.nix
        ];
      };
    };
}
