# Every mailbox and calendar, declared once.
#
# Everything else is generated from this file: mbsync (fetch), msmtp (send),
# notmuch (search/read in Emacs), vdirsyncer + khal (calendars → org-agenda)
# and Thunderbird (GUI fallback). How each provider works lives in
# ./providers.nix; the tooling lives in ./mail.nix and ./calendar.nix.
{ config, lib, pkgs, ... }:

let
  p = import ./providers.nix { inherit config lib pkgs; };
in
{
  accounts.email.accounts = {
    weast-studios          = p.purelymail "william@weast-studios.com" // { primary = true; };
    weast-studios-accounts = p.purelymail "accounts@weast-studios.com";
    weast-studios-hello    = p.purelymail "hello@weast-studios.com";
    aquaveen               = p.purelymail "hello@aquaveen.com";
    bogen                  = p.purelymail "william@bogen43.de";
    gmail                  = p.gmail "williameast1994@gmail.com";
    live                   = p.outlook "williameast@live.com";
    mcgill                 = p.office365 "william.east@mail.mcgill.ca";
  };

  accounts.calendar.accounts = {
    google     = p.googleCalendar "williameast1994@gmail.com" // { primary = true; };
    purelymail = p.purelymailCalendar "william@weast-studios.com";
    mcgill     = p.office365Calendar "william.east@mail.mcgill.ca";
    # Outlook.com has no CalDAV: publish the calendar as ICS
    # (outlook.live.com → Settings → Calendar → Shared calendars → Publish)
    # and store the ICS link as agenix secret "outlook-calendar-ics" (see secrets.nix).
    live       = p.icsCalendar "outlook-calendar-ics";
  };
}
