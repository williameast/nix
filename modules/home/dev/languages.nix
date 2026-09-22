# Language servers, formatters, and development tools
{
  config,
  pkgs,
  lib,
  ...
}:

{
  home.packages = with pkgs; [
    # Shell
    shellcheck

    # JavaScript/TypeScript
    nodejs
    js-beautify
    vscode-langservers-extracted
    bash-language-server
    prettier

    # HTML/CSS
    html-tidy

    # Python
    # poetry  # Use pipx or devshell - nixpkgs version has dependency conflicts
    black

    # Nix
    # nixfmt TODO not working?

    # LaTeX
    texliveSmall
    pandoc

    # R
    rWrapper

    # Java (for some Doom Emacs features)
    jdk
  ];
}
