# Common CLI tools
{ config, pkgs, lib, ... }:

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
  ];
}
