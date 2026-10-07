# Secrets for mail and calendar sync, encrypted with agenix (files in ../../../secrets).
# They are decrypted at login into /run/user/1000/agenix with the SSH key below,
# so background syncs never need a password manager to be unlocked.
#
# Add or change one:  cd secrets && rage -e -R ~/.ssh/id_ed25519.pub -o NAME.age
# (type the value, then Ctrl-D), then `git add` the file before rebuilding.
{ config, lib, inputs, ... }:

let
  names = [
    # Mailbox passwords, named after the address.
    "william_at_weast-studios_com"
    "accounts_at_weast-studios_com"
    "hello_at_weast-studios_com"
    "hello_at_aquaveen_com"
    "william_at_bogen43_de"
    "william_east_at_mail_mcgill_ca"
    # Google OAuth client (shared by vdirsyncer and oama).
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
