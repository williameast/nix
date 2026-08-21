# Communications - email client and accounts
{ config, pkgs, lib, ... }:

{
  programs.thunderbird = {
    enable = true;
    profiles.default.isDefault = true;
  };

  accounts.email.accounts = {
    mcgill = {
      address = "william.east@mail.mcgill.ca";
      realName = "William East";
      userName = "william.east@mail.mcgill.ca";
      imap = { host = "outlook.office365.com"; port = 993; tls.enable = true; };
      smtp = { host = "smtp.office365.com"; port = 587; tls.enable = true; tls.useStartTls = true; };
      thunderbird.enable = true;
    };

    live = {
      address = "williameast@live.com";
      realName = "William East";
      userName = "williameast@live.com";
      imap = { host = "outlook.office365.com"; port = 993; tls.enable = true; };
      smtp = { host = "smtp.office365.com"; port = 587; tls.enable = true; tls.useStartTls = true; };
      thunderbird.enable = true;
    };

    gmail = {
      address = "williameast1994@gmail.com";
      realName = "William East";
      userName = "williameast1994@gmail.com";
      flavor = "gmail.com";
      thunderbird.enable = true;
    };

    weast-studios = {
      address = "william@weast-studios.com";
      realName = "William East";
      primary = true;
      userName = "william@weast-studios.com";
      imap = { host = "imap.purelymail.com"; port = 993; tls.enable = true; };
      smtp = { host = "smtp.purelymail.com"; port = 587; tls.enable = true; tls.useStartTls = true; };
      thunderbird.enable = true;
    };

    weast-studios-accounts = {
      address = "accounts@weast-studios.com";
      realName = "William East";
      userName = "accounts@weast-studios.com";
      imap = { host = "imap.purelymail.com"; port = 993; tls.enable = true; };
      smtp = { host = "smtp.purelymail.com"; port = 587; tls.enable = true; tls.useStartTls = true; };
      thunderbird.enable = true;
    };
  };
}
