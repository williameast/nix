# Zsh configuration with Oh-My-Zsh
{
  config,
  pkgs,
  lib,
  ...
}:

{
  programs.zsh = {
    enable = true;
    autosuggestion.enable = true;
    enableCompletion = true;
    syntaxHighlighting.enable = true;

    # Use XDG config directory for zsh files (new default in HM 26.05+)
    dotDir = "${config.xdg.configHome}/zsh";

    # Session variables (machine-specific ones go in hosts/)
    sessionVariables = {
      MAIL = "weast@student.42berlin.de";
    };

    # Prepend ~/.local/bin to PATH (for nixGL wrappers to take precedence)
    initContent = ''
      export PATH="$HOME/.local/bin:$PATH"
    '';

    shellAliases = {
      # Emacs
      e = "emacsclient -c";
      ddr = "systemctl --user restart emacs.service";

      # Better defaults
      cat = "bat";

      # Utilities
      ducks = "du -cks * | sort -rn | head -n 20";
      flatten_dir = "find . -type f -exec mv -t . {} +";

      # Passwords
      kxc = "keepassxc-cli";
    };

    oh-my-zsh = {
      enable = true;
      theme = "robbyrussell";
      plugins = [
        "git"
        "per-directory-history"
        "sudo"
        "colored-man-pages"
        "web-search"
        "copyfile"
      ];
    };
  };

  home.packages = with pkgs; [
    zsh
  ];
}
