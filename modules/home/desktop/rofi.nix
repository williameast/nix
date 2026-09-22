# Rofi launcher configuration
{ config, pkgs, lib, ... }:

{
  programs.rofi = {
    enable = true;
    package = pkgs.rofi;  # Wayland-native rofi (rofi-wayland merged upstream)

    settings = {
      terminal = "${pkgs.alacritty}/bin/alacritty";
      modi = "drun,run,window,ssh";
      show-icons = true;
      drun-display-format = "{name}";
      disable-history = false;
      hide-scrollbar = true;
      display-drun = "  Apps";
      display-run = "  Run";
      display-window = "  Windows";
      display-ssh = "  SSH";
      sidebar-mode = true;
    };

    theme = let
      inherit (config.lib.formats.rasi) mkLiteral;
    in {
      "*" = {
        bg-col = mkLiteral "#141118";
        bg-col-light = mkLiteral "#3d2a42";
        border-col = mkLiteral "#d4434a";
        selected-col = mkLiteral "#5a3a50";
        accent = mkLiteral "#d4434a";
        fg-col = mkLiteral "#c0b8c8";
        fg-col2 = mkLiteral "#e06c75";
        grey = mkLiteral "#7a6880";
        width = 600;
      };

      "element-text, element-icon, mode-switcher" = {
        background-color = mkLiteral "inherit";
        text-color = mkLiteral "inherit";
      };

      "window" = {
        height = mkLiteral "400px";
        border = mkLiteral "2px";
        border-color = mkLiteral "@border-col";
        background-color = mkLiteral "@bg-col";
        border-radius = mkLiteral "8px";
      };

      "mainbox" = {
        background-color = mkLiteral "@bg-col";
      };

      "inputbar" = {
        children = mkLiteral "[prompt,entry]";
        background-color = mkLiteral "@bg-col-light";
        border-radius = mkLiteral "5px";
        padding = mkLiteral "8px";
      };

      "prompt" = {
        background-color = mkLiteral "@accent";
        padding = mkLiteral "6px";
        text-color = mkLiteral "@bg-col";
        border-radius = mkLiteral "3px";
        margin = mkLiteral "0px 8px 0px 0px";
      };

      "textbox-prompt-colon" = {
        expand = false;
        str = ":";
      };

      "entry" = {
        padding = mkLiteral "6px";
        text-color = mkLiteral "@fg-col";
        background-color = mkLiteral "@bg-col-light";
      };

      "listview" = {
        border = mkLiteral "0px 0px 0px";
        padding = mkLiteral "6px 0px 0px";
        columns = 1;
        lines = 8;
        background-color = mkLiteral "@bg-col";
      };

      "element" = {
        padding = mkLiteral "8px";
        background-color = mkLiteral "@bg-col";
        text-color = mkLiteral "@fg-col";
        border-radius = mkLiteral "5px";
      };

      "element-icon" = {
        size = mkLiteral "25px";
      };

      "element selected" = {
        background-color = mkLiteral "@selected-col";
        text-color = mkLiteral "@fg-col2";
      };

      "mode-switcher" = {
        spacing = 0;
      };

      "button" = {
        padding = mkLiteral "10px";
        background-color = mkLiteral "@bg-col-light";
        text-color = mkLiteral "@grey";
        vertical-align = mkLiteral "0.5";
        horizontal-align = mkLiteral "0.5";
      };

      "button selected" = {
        background-color = mkLiteral "@bg-col";
        text-color = mkLiteral "@accent";
      };

      "message" = {
        background-color = mkLiteral "@bg-col-light";
        border = mkLiteral "2px 0px 0px";
        border-color = mkLiteral "@border-col";
        padding = mkLiteral "8px";
      };

      "textbox" = {
        padding = mkLiteral "6px";
        text-color = mkLiteral "@fg-col";
        background-color = mkLiteral "@bg-col-light";
      };
    };
  };
}
