# XDG Base Directory configuration
# Goal: Keep $HOME clean - all config/data/cache in XDG directories
{ config, pkgs, lib, ... }:

{
  xdg = {
    enable = true;
    userDirs = {
      enable = true;
      createDirectories = true;
    };
  };

  # Force XDG compliance for programs that don't respect it by default
  home.sessionVariables = {
    # Shell history
    HISTFILE = "${config.xdg.stateHome}/bash/history";
    LESSHISTFILE = "${config.xdg.stateHome}/less/history";

    # Node.js
    NODE_REPL_HISTORY = "${config.xdg.stateHome}/node/repl_history";
    NPM_CONFIG_USERCONFIG = "${config.xdg.configHome}/npm/npmrc";

    # Rust toolchain
    CARGO_HOME = "${config.xdg.dataHome}/cargo";
    RUSTUP_HOME = "${config.xdg.dataHome}/rustup";

    # GnuPG
    GNUPGHOME = "${config.xdg.dataHome}/gnupg";

    # Wget
    WGETRC = "${config.xdg.configHome}/wget/wgetrc";

    # Zsh (will use ZDOTDIR if set)
    ZDOTDIR = "${config.xdg.configHome}/zsh";
  };

  # Create required directories
  home.file."${config.xdg.stateHome}/bash/.keep".text = "";
  home.file."${config.xdg.stateHome}/less/.keep".text = "";
  home.file."${config.xdg.stateHome}/node/.keep".text = "";
  home.file."${config.xdg.configHome}/npm/.keep".text = "";
  home.file."${config.xdg.configHome}/wget/.keep".text = "";
}
