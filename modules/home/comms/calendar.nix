# Calendar tooling for the calendars in ./accounts.nix:
# vdirsyncer syncs them to ~/.local/share/calendars as .ics files, khal reads
# them, and Emacs (khalel) imports them into ~/org/calendar.org for org-agenda.
{ config, lib, pkgs, ... }:

{
  accounts.calendar.basePath = "${config.xdg.dataHome}/calendars";

  programs.vdirsyncer = {
    enable = true;
    statusPath = "${config.xdg.stateHome}/vdirsyncer";
  };

  services.vdirsyncer = {
    enable = true;
    frequency = "*:0/15";
  };

  programs.khal = {
    enable = true;
    locale = {
      timeformat = "%H:%M";
      dateformat = "%d.%m.%Y";
      longdateformat = "%d.%m.%Y";
      datetimeformat = "%d.%m.%Y %H:%M";
      longdatetimeformat = "%d.%m.%Y %H:%M";
      firstweekday = 0;
    };
  };
}
