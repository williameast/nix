# Emacs configuration for Doom Emacs
# Automatically sets up Doom + user config from git
{ config, pkgs, lib, ... }:

let
  doomRepoUrl = "https://github.com/doomemacs/doomemacs";
  doomConfigUrl = "https://github.com/williameast/doom.git";
  emacsDir = "${config.home.homeDirectory}/.config/emacs";
  doomDir = "${config.home.homeDirectory}/.config/doom";
in {
  programs.emacs = {
    enable = true;
    extraPackages = epkgs: [
      epkgs.vterm
      epkgs.pdf-tools  # Precompiled from nixpkgs, avoids build issues
    ];
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

    # Spell checking (doom config uses hunspell with en_GB / de_DE)
    (hunspell.withDicts (dicts: with dicts; [ en_GB-ise de_DE ]))
    (aspellWithDicts (dicts: with dicts; [ de en en-computers en-science ]))

    # Fonts
    emacs-all-the-icons-fonts
    symbola  # Emacs' fallback font; doom doctor warns without it

    # For LSP and other features
    shellcheck
    nixfmt
  ];

  # Add Doom's bin to PATH
  home.sessionPath = [ "${emacsDir}/bin" ];

  # Clone Doom Emacs and user config on activation
  home.activation = {
    installDoomEmacs = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
      # Clone Doom Emacs if bin/doom is not present
      if [ ! -f "${emacsDir}/bin/doom" ]; then
        $DRY_RUN_CMD rm -rf "${emacsDir}"
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
