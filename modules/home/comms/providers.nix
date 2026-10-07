# How to talk to each mail/calendar provider. Used by ./accounts.nix.
#
# Passwords and OAuth client secrets are agenix secrets (./secrets.nix),
# decrypted at login to files that the sync tools simply `cat`.
# OAuth tokens for Gmail and Outlook.com are kept by oama (in the keyring).
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

  # Mailbox that signs in with OAuth2 through oama.
  oauthMailbox = address: lib.recursiveUpdate mailbox {
    passwordCommand = [ "${pkgs.oama}/bin/oama" "access" address ];
    mbsync.extraConfig.account.AuthMechs = "XOAUTH2";
    msmtp.extraConfig.auth = "xoauth2";
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
  # Purelymail (weast-studios.com, aquaveen.com): plain password login.
  purelymail = address: lib.recursiveUpdate mailbox {
    inherit address;
    userName = address;
    passwordCommand = secretSh (addressSecret address);
    imap = { host = "imap.purelymail.com"; port = 993; tls.enable = true; };
    smtp = { host = "smtp.purelymail.com"; port = 587; tls = { enable = true; useStartTls = true; }; };
  };

  # Gmail: OAuth2 via oama. Labels are folders over IMAP, so only the useful
  # ones are synced; notmuch de-duplicates messages that appear in several.
  gmail = address: lib.recursiveUpdate (oauthMailbox address) {
    inherit address;
    flavor = "gmail.com";
    folders = {
      inbox = "Inbox";
      sent = "[Gmail]/Sent Mail";
      drafts = "[Gmail]/Drafts";
      trash = "[Gmail]/Trash";
    };
    mbsync.patterns = [ "INBOX" "[Gmail]/All Mail" "[Gmail]/Sent Mail" "[Gmail]/Drafts" "[Gmail]/Trash" ];
  };

  # Outlook.com / live.com personal account: OAuth2 via oama.
  outlook = address: lib.recursiveUpdate (oauthMailbox address) {
    inherit address;
    flavor = "outlook.office365.com";
    folders = { sent = "Sent"; drafts = "Drafts"; trash = "Deleted"; };
  };

  # Microsoft 365 work/university account through the local DavMail gateway,
  # which signs in as Outlook (allowed by most tenants) and also serves CalDAV.
  office365 = address: lib.recursiveUpdate mailbox {
    inherit address;
    flavor = "davmail";
    userName = address;
    passwordCommand = secretSh (addressSecret address);
    # DavMail serves plain IMAP/SMTP on localhost.
    imap.tls.enable = false;
    mbsync.extraConfig.account.AuthMechs = "LOGIN";
    folders = { sent = "Sent"; drafts = "Drafts"; trash = "Trash"; };
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

  office365Calendar = address: lib.recursiveUpdate calendar {
    remote = {
      type = "caldav";
      url = "http://localhost:1080/users/${address}/";
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
