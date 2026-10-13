# How to talk to each mail/calendar provider. Used by ./accounts.nix.
#
# Passwords and OAuth client secrets are agenix secrets (./secrets.nix),
# decrypted at login to files that the sync tools simply `cat`.
# No keyring or password manager is involved.
{ config, lib, pkgs }:

let
  cat = "${pkgs.coreutils}/bin/cat";

  # Secret holding the password of the mailbox ADDRESS.
  addressSecret = address:
    lib.replaceStrings [ "@" "." ] [ "_at_" "_" ] address;

  secretPath = name: config.age.secrets.${name}.path;

  # Command printing the secret NAME.
  secret = name: [ cat (secretPath name) ];

  # Same as a shell command string (mbsync and msmtp run it through sh).
  secretSh = name: "${cat} ${secretPath name}";

  # Settings every mailbox shares.
  mailbox = {
    realName = "William East";
    thunderbird.enable = true;
    notmuch.enable = true;
    msmtp.enable = true;
    mbsync = {
      enable = true;
      create = "maildir";
      expunge = "both";
    };
  };

  calendar = {
    vdirsyncer = {
      enable = true;
      collections = [ "from a" "from b" ];
      conflictResolution = "remote wins";
    };
    khal = {
      enable = true;
      type = "discover";
    };
  };
in
{
  inherit addressSecret;

  # Purelymail (weast-studios.com, aquaveen.com): plain password login.
  purelymail = address: lib.recursiveUpdate mailbox {
    inherit address;
    userName = address;
    passwordCommand = secretSh (addressSecret address);
    imap = { host = "imap.purelymail.com"; port = 993; tls.enable = true; };
    smtp = { host = "smtp.purelymail.com"; port = 587; tls = { enable = true; useStartTls = true; }; };
  };

  googleCalendar = address: lib.recursiveUpdate calendar {
    remote.type = "google_calendar";
    vdirsyncer = {
      tokenFile = "${config.xdg.stateHome}/vdirsyncer/google-${address}.token";
      clientIdCommand = secret "google-client-id";
      clientSecretCommand = secret "google-client-secret";
    };
  };

  purelymailCalendar = address: lib.recursiveUpdate calendar {
    remote = {
      type = "caldav";
      url = "https://purelymail.com/";
      userName = address;
      passwordCommand = secret (addressSecret address);
    };
  };

  # Read-only calendar published as an .ics link decrypted by agenix.
  icsCalendar = title: {
    remote.type = "http";
    vdirsyncer = {
      enable = true;
      urlCommand = secret title;
    };
    khal = {
      enable = true;
      type = "calendar";
      readOnly = true;
    };
  };
}
