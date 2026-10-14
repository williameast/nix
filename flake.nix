{
  description = "weast's NixOS + Home Manager configuration";

  inputs = {
    # Core inputs
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";

    home-manager = {
      url = "github:nix-community/home-manager";
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

    agenix = {
      url = "github:ryantm/agenix";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # Affinity suite for Linux
    affinity-nix.url = "github:mrshmllow/affinity-nix";
  };

  outputs = { nixpkgs, ... }@inputs:
    let
      system = "x86_64-linux";
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
