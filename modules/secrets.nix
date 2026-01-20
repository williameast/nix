# Secrets management via KeePassXC
# Secrets stay in your .kdbx file, fetched at runtime with keepassxc-cli
{ config, pkgs, lib, ... }:

{
  home.packages = with pkgs; [
    keepassxc  # Full app (desktop machines)
  ];

  # Helper aliases for fetching secrets
  programs.zsh.shellAliases = {
    # Fetch password: kxp <database> <entry>
    kxp = "keepassxc-cli show -s -a password";
    # Fetch username: kxu <database> <entry>
    kxu = "keepassxc-cli show -s -a username";
    # Fetch attribute: kxa <database> <entry> <attribute>
    kxa = "keepassxc-cli show -s -a";
  };

  # Environment variable pointing to default database (customize path as needed)
  home.sessionVariables = {
    KEEPASSXC_DB = "${config.home.homeDirectory}/Sync/passwords.kdbx";
  };
}
