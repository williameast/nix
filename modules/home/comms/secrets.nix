# Secrets for mail and calendar sync, encrypted with agenix (files in ../../../secrets).
# They are decrypted at login into /run/user/1000/agenix with the SSH key below,
# so background syncs never need a password manager to be unlocked.
#
# New mailbox: run `mail-add` (see ./mail.nix); it encrypts the password and
# adds the account to ./accounts.nix.
# Other secrets: cd secrets && rage -e -R ~/.ssh/id_ed25519.pub -o NAME.age
# (type the value, then Ctrl-D), then `git add` the file before rebuilding.
{ config, lib, pkgs, inputs, ... }:

let
  p = import ./providers.nix { inherit config lib pkgs; };

  # Mailbox passwords, named after the address of every account in ./accounts.nix.
  mailboxes = lib.mapAttrsToList (_: a: p.addressSecret a.address) config.accounts.email.accounts;

  names = mailboxes ++ [
    # Google OAuth client (vdirsyncer).
    "google-client-id"
    "google-client-secret"
    # Published ICS link of the Outlook.com calendar.
    "outlook-calendar-ics"
  ];
in
{
  imports = [ inputs.agenix.homeManagerModules.default ];

  age = {
    identityPaths = [ "${config.home.homeDirectory}/.ssh/id_ed25519" ];
    secretsDir = "/run/user/1000/agenix";
    secrets = lib.genAttrs names (n: { file = ../../../secrets/${n}.age; });
  };
}
