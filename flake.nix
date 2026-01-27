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
  };

  outputs = { self, nixpkgs, home-manager, nixgl, nur, ... }@inputs:
    let
      system = "x86_64-linux";
      pkgs = import nixpkgs {
        inherit system;
        config.allowUnfree = true;
      };
    in {
      # Home Manager configurations (for non-NixOS systems: orr, yossarian)
      homeConfigurations."weast@orr" = home-manager.lib.homeManagerConfiguration {
        inherit pkgs;

        # Pass inputs to all modules
        extraSpecialArgs = { inherit inputs; };

        modules = [
          ./hosts/orr/default.nix
        ];
      };

      homeConfigurations."weast@yossarian" = home-manager.lib.homeManagerConfiguration {
        inherit pkgs;

        # Pass inputs to all modules
        extraSpecialArgs = { inherit inputs; };

        modules = [
          ./hosts/yossarian/default.nix
        ];
      };

      # NixOS system configuration (milo server)
      nixosConfigurations.milo = nixpkgs.lib.nixosSystem {
        inherit system;

        modules = [
          ./hosts/milo/configuration.nix
        ];
      };
    };
}
