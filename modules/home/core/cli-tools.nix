# Common CLI tools
{ config, pkgs, lib, inputs, ... }:

{
  # Enhanced CLI tools
  programs.bat.enable = true;

  programs.fzf = {
    enable = true;
    enableZshIntegration = true;
  };

  home.packages = with pkgs; [
    # Search
    ripgrep
    fd

    # File management
    tree
    unzip

    # System monitoring
    htop

    # Secrets
    rage

    # AI assistant
    # TODO: claude-code 2.1.52 has packaging bug, keeping 2.0.55 from profile for now
    # inputs.claude-code.packages.${pkgs.system}.default
  ];
}
