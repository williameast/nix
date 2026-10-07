# How to talk to each mail/calendar provider. Used by ./accounts.nix.
#
# Secrets come from KeePassXC over the Secret Service API (KeePassXC →
# Settings → Secret Service Integration, then expose the group holding these
# entries). Entries are looked up by title:
#   <email address>          password of that mailbox (Purelymail, McGill)
#   calendar.google.com      Google OAuth client (UserName = client id, Password = secret)
#   outlook-calendar-ics     Password = published ICS link of the Outlook.com calendar
# OAuth tokens for Gmail and Outlook.com are kept by oama (also in the keyring).
{ config, lib, pkgs }:

let
  secretTool = "${pkgs.libsecret}/bin/secret-tool";

  # Command printing the password of the KeePassXC entry titled TITLE.
  secret = title: [ secretTool "lookup" "Title" title ];

  # Same as a shell command string (mbsync and msmtp run it through sh).
  secretSh = title: "${secretTool} lookup Title ${lib.escapeShellArg title}";

  # Command printing the UserName field of the KeePassXC entry titled TITLE.
  secretUser = title: [
    "${pkgs.bash}/bin/sh" "-c"
    "${secretTool} search Title ${lib.escapeShellArg title} 2>&1 | ${pkgs.gnused}/bin/sed -n 's/^attribute.UserName = //p'"
  ];

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
    passwordCommand = secretSh address;
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
    passwordCommand = secretSh address;
    folders = { sent = "Sent"; drafts = "Drafts"; trash = "Trash"; };
  };

  googleCalendar = address: lib.recursiveUpdate calendar {
    remote.type = "google_calendar";
    vdirsyncer = {
      tokenFile = "${config.xdg.stateHome}/vdirsyncer/google-${address}.token";
      clientIdCommand = secretUser "calendar.google.com";
      clientSecretCommand = secret "calendar.google.com";
    };
  };

  purelymailCalendar = address: lib.recursiveUpdate calendar {
    remote = {
      type = "caldav";
      url = "https://purelymail.com/";
      userName = address;
      passwordCommand = secret address;
    };
  };

  office365Calendar = address: lib.recursiveUpdate calendar {
    remote = {
      type = "caldav";
      url = "http://localhost:1080/users/${address}/";
      userName = address;
      passwordCommand = secret address;
    };
  };

  # Read-only calendar published as an .ics link stored in KeePassXC.
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
