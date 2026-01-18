# Emacs configuration for Doom Emacs
# Uses current Emacs from nixpkgs (not pinned)
{ config, pkgs, lib, ... }:

{
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
  ];
}
