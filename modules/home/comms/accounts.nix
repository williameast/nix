# Every mailbox and calendar, declared once.
#
# Everything else is generated from this file: mbsync (fetch), msmtp (send),
# Thunderbird (main client), notmuch (search/read in Emacs) and vdirsyncer +
# khal (calendars → org-agenda). How each provider works lives in
# ./providers.nix; the tooling lives in ./mail.nix and ./calendar.nix.
{ config, lib, pkgs, ... }:

let
  p = import ./providers.nix { inherit config lib pkgs; };
in
{
  accounts.email.accounts = {
    # Gmail, Outlook.com and McGill are not synced: they forward to a
    # Purelymail address instead.
    weast-studios          = p.purelymail "william@weast-studios.com" // { primary = true; };
    weast-studios-accounts = p.purelymail "accounts@weast-studios.com";
    weast-studios-hello    = p.purelymail "hello@weast-studios.com";
    aquaveen               = p.purelymail "hello@aquaveen.com";
    bogen                  = p.purelymail "william@bogen43.de";
    oldmail                = p.purelymail "oldmail@weast-studios.com";
  };

  accounts.calendar.accounts = {
    google     = p.googleCalendar "williameast1994@gmail.com" // { primary = true; };
    purelymail = p.purelymailCalendar "william@weast-studios.com";
    # Outlook.com has no CalDAV: publish the calendar as ICS
    # (outlook.live.com → Settings → Calendar → Shared calendars → Publish)
    # and store the ICS link as agenix secret "outlook-calendar-ics" (see secrets.nix).
    live       = p.icsCalendar "outlook-calendar-ics";
  };
}
