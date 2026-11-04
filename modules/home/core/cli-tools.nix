# Common CLI tools
{ config, pkgs, lib, inputs, ... }:

{
  imports = [ inputs.nix-index-database.homeModules.nix-index ];

  # Enhanced CLI tools
  programs.bat.enable = true;

  programs.fzf = {
    enable = true;
    enableZshIntegration = true;
    historyWidget.command = "";  # Ctrl+R belongs to atuin; Ctrl+T/Alt+C stay fzf
  };

  # `z proj` jumps to frecent directories (`zi` picks with fzf)
  programs.zoxide = {
    enable = true;
    enableZshIntegration = true;
  };

  # ls replacement (ls/ll/la/lt aliases), with icons and git status
  programs.eza = {
    enable = true;
    enableZshIntegration = true;
    icons = "auto";
    git = true;
  };

  # Shell history in SQLite, synced via milo (services/atuin.nix).
  # Ctrl+R searches; Up arrow stays plain zsh history.
  programs.atuin = {
    enable = true;
    enableZshIntegration = true;
    flags = [ "--disable-up-arrow" ];
    settings = {
      sync_address = "http://milo:8888";
      auto_sync = true;
      sync_frequency = "5m";
      style = "compact";
      inline_height = 20;
      filter_mode_shell_up_key_binding = "directory";
    };
  };

  programs.lazygit.enable = true;

  # `tldr <cmd>`: short, example-first man pages
  programs.tealdeer = {
    enable = true;
    settings.updates.auto_update = true;
  };

  # `, <cmd>` runs any nixpkgs program without installing it; unknown
  # commands print which package provides them
  programs.nix-index-database.comma.enable = true;
  programs.nix-index.enableZshIntegration = true;

  home.packages = with pkgs; [
    # Search
    ripgrep
    fd

    # File management
    tree
    unzip
    dust  # visual du

    # System monitoring
    htop
    psmisc  # killall, fuser, pstree

    # Secrets
    rage

    # AI assistant
    inputs.claude-code.packages.${pkgs.stdenv.hostPlatform.system}.default
    # Gitea CLI: lets Claude background jobs open pull requests on milo
    tea
  ];
}
