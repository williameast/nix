# Communications - mail, calendars, chat
# Accounts and calendars are declared once in ./accounts.nix.
{ config, pkgs, lib, ... }:

{
  imports = [
    ./accounts.nix
    ./mail.nix
    ./calendar.nix
    ./secrets.nix
  ];

  home.packages = with pkgs; [
    external-editor-revived  # Native messaging host for editing emails in Emacs
    discord
  ];

  # GUI fallback; gets the same accounts from ./accounts.nix.
  programs.thunderbird = {
    enable = true;
    profiles.default.isDefault = true;
  };
}
