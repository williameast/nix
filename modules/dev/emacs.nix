# Emacs configuration for Doom Emacs
# Automatically sets up Doom + user config from git
{ config, pkgs, lib, ... }:

let
  doomRepoUrl = "https://github.com/doomemacs/doomemacs";
  doomConfigUrl = "git@github.com:williameast/doom.git";
  emacsDir = "${config.home.homeDirectory}/.config/emacs";
  doomDir = "${config.home.homeDirectory}/.config/doom";
in {
  programs.emacs = {
    enable = true;
    # vterm needs native compilation
    extraPackages = epkgs: [ epkgs.vterm ];
  };

  # Start emacs daemon on login
  services.emacs.enable = true;

  # Doom Emacs dependencies and tools
  home.packages = with pkgs; [
    # Core tools Doom needs
    binutils
    fd
    gnutls
    imagemagick
    sqlite
    zstd

    # Spell checking
    hunspell
    (aspellWithDicts (dicts: with dicts; [ de en en-computers en-science ]))

    # Fonts
    emacs-all-the-icons-fonts

    # For LSP and other features
    shellcheck
    nixfmt-classic
  ];

  # Add Doom's bin to PATH
  home.sessionPath = [ "${emacsDir}/bin" ];

  # Clone Doom Emacs and user config on activation
  home.activation = {
    installDoomEmacs = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
      # Clone Doom Emacs if not present
      if [ ! -d "${emacsDir}" ]; then
        $DRY_RUN_CMD ${pkgs.git}/bin/git clone --depth 1 ${doomRepoUrl} "${emacsDir}"
        echo "Doom Emacs cloned. Run 'doom install' to complete setup."
      fi

      # Clone doom config if not present
      if [ ! -d "${doomDir}" ]; then
        $DRY_RUN_CMD ${pkgs.git}/bin/git clone ${doomConfigUrl} "${doomDir}"
        echo "Doom config cloned from ${doomConfigUrl}"
      fi
    '';
  };

  # Environment variables for Doom
  home.sessionVariables = {
    DOOMDIR = doomDir;
    EMACSDIR = emacsDir;
  };
}
