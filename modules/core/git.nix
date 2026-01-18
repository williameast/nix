# Git configuration
{ config, pkgs, lib, ... }:

{
  programs.git = {
    enable = true;

    settings = {
      user = {
        name = "William East";
        email = "william.east@mail.mcgill.ca";
      };
      core.editor = "emacs";
      credential.helper = "cache";  # Cache credentials for 15 mins
      init.defaultBranch = "main";
    };
  };
}
