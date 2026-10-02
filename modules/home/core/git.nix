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
      # Open in the running Emacs daemon (fast, in this terminal); vi if it's down
      core.editor = "emacsclient -t -a vi";
      credential.helper = "cache";  # Cache credentials for 15 mins
      init.defaultBranch = "main";
    };
  };
}
