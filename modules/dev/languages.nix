# Language servers, formatters, and development tools
{ config, pkgs, lib, ... }:

{
  home.packages = with pkgs; [
    # Shell
    shellcheck

    # JavaScript/TypeScript
    nodejs
    nodePackages.js-beautify
    nodePackages.vscode-langservers-extracted
    nodePackages.bash-language-server
    nodePackages.prettier

    # HTML/CSS
    html-tidy

    # Python
    # poetry  # Use pipx or devshell - nixpkgs version has dependency conflicts
    black

    # Nix
    nixfmt

    # LaTeX
    texlive.combined.scheme-full
    pandoc

    # R
    rWrapper

    # Java (for some Doom Emacs features)
    jdk
  ];
}
