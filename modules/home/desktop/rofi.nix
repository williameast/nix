# Rofi launcher configuration
{ config, pkgs, lib, ... }:

{
  programs.rofi = {
    enable = true;
    package = pkgs.rofi-wayland;  # Wayland-native rofi

    terminal = "${pkgs.alacritty}/bin/alacritty";

    extraConfig = {
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
        bg-col = mkLiteral "#1e1e2e";
        bg-col-light = mkLiteral "#313244";
        border-col = mkLiteral "#89b4fa";
        selected-col = mkLiteral "#45475a";
        blue = mkLiteral "#89b4fa";
        fg-col = mkLiteral "#cdd6f4";
        fg-col2 = mkLiteral "#f38ba8";
        grey = mkLiteral "#6c7086";
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
        background-color = mkLiteral "@blue";
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
        text-color = mkLiteral "@blue";
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
