# Niri compositor configuration
{ config, pkgs, lib, ... }:

{
  home.packages = with pkgs; [
    niri
    alacritty       # Terminal emulator
    # Niri utilities
    waybar          # Status bar
    mako            # Notification daemon
    swaylock        # Screen locker
    grim            # Screenshot tool
    slurp           # Region selector
    wl-clipboard    # Clipboard utilities
  ];

  # Niri configuration
  xdg.configFile."niri/config.kdl".text = ''
    // Niri configuration
    // See: https://github.com/YaLTeR/niri/wiki/Configuration:-Overview

    input {
        keyboard {
            xkb {
                layout "us"
            }
        }

        touchpad {
            tap
            natural-scroll
            accel-speed 0.3
        }

        mouse {
            accel-speed 0.3
        }
    }

    output "eDP-1" {
        mode "1920x1080@60.000"
        scale 1.0
    }

    layout {
        gaps 8
        center-focused-column "never"

        default-column-width { proportion 0.5; }

        preset-column-widths {
            proportion 0.33
            proportion 0.5
            proportion 0.67
        }

        focus-ring {
            width 2
            active-color "#7fc8ff"
            inactive-color "#505050"
        }

        border {
            width 1
            active-color "#505050"
            inactive-color "#303030"
        }
    }

    prefer-no-csd

    screenshot-path "~/Pictures/Screenshots/screenshot-%Y-%m-%d_%H-%M-%S.png"

    // Hotkey mod is Super
    hotkey-overlay {
        skip-at-startup
    }

    binds {
        // Mod key
        Mod+Return { spawn "alacritty"; }
        Mod+D { spawn "rofi" "-show" "drun"; }
        Mod+Q { close-window; }

        // Screenshots
        Print { screenshot; }
        Mod+Print { screenshot-screen; }
        Mod+Shift+Print { screenshot-window; }

        // Movement
        Mod+H { focus-column-left; }
        Mod+L { focus-column-right; }
        Mod+J { focus-window-down; }
        Mod+K { focus-window-up; }
        Mod+Left { focus-column-left; }
        Mod+Right { focus-column-right; }
        Mod+Down { focus-window-down; }
        Mod+Up { focus-window-up; }

        // Move windows
        Mod+Shift+H { move-column-left; }
        Mod+Shift+L { move-column-right; }
        Mod+Shift+J { move-window-down; }
        Mod+Shift+K { move-window-up; }
        Mod+Shift+Left { move-column-left; }
        Mod+Shift+Right { move-column-right; }
        Mod+Shift+Down { move-window-down; }
        Mod+Shift+Up { move-window-up; }

        // Column width
        Mod+R { switch-preset-column-width; }
        Mod+Shift+R { reset-window-height; }
        Mod+F { maximize-column; }
        Mod+Shift+F { fullscreen-window; }

        // Workspaces
        Mod+1 { focus-workspace 1; }
        Mod+2 { focus-workspace 2; }
        Mod+3 { focus-workspace 3; }
        Mod+4 { focus-workspace 4; }
        Mod+5 { focus-workspace 5; }
        Mod+6 { focus-workspace 6; }
        Mod+7 { focus-workspace 7; }
        Mod+8 { focus-workspace 8; }
        Mod+9 { focus-workspace 9; }

        Mod+Shift+1 { move-column-to-workspace 1; }
        Mod+Shift+2 { move-column-to-workspace 2; }
        Mod+Shift+3 { move-column-to-workspace 3; }
        Mod+Shift+4 { move-column-to-workspace 4; }
        Mod+Shift+5 { move-column-to-workspace 5; }
        Mod+Shift+6 { move-column-to-workspace 6; }
        Mod+Shift+7 { move-column-to-workspace 7; }
        Mod+Shift+8 { move-column-to-workspace 8; }
        Mod+Shift+9 { move-column-to-workspace 9; }

        // Monitor movement
        Mod+Comma { focus-monitor-left; }
        Mod+Period { focus-monitor-right; }
        Mod+Shift+Comma { move-column-to-monitor-left; }
        Mod+Shift+Period { move-column-to-monitor-right; }

        // Exit
        Mod+Shift+E { quit; }

        // Lock screen
        Mod+Escape { spawn "swaylock"; }
    }

    // Window rules
    window-rule {
        match app-id="^firefox$"
        default-column-width { proportion 0.67; }
    }

    window-rule {
        match app-id="^org.keepassxc.KeePassXC$"
        default-column-width { proportion 0.33; }
    }

    cursor {
        xcursor-theme "Adwaita"
        xcursor-size 24
    }

    environment {
        // Set environment variables for Wayland
        QT_QPA_PLATFORM "wayland"
        MOZ_ENABLE_WAYLAND "1"
        NIXOS_OZONE_WL "1"
    }
  '';

  # Swaylock configuration
  xdg.configFile."swaylock/config".text = ''
    daemonize
    show-failed-attempts
    color=1e1e2e
    font=Inter
    indicator-radius=120
    indicator-thickness=8
    line-color=00000000
    ring-color=313244
    inside-color=1e1e2e
    text-color=cdd6f4
    ring-ver-color=89b4fa
    inside-ver-color=1e1e2e
    ring-wrong-color=f38ba8
    inside-wrong-color=1e1e2e
  '';

  # Mako notification daemon config
  services.mako = {
    enable = true;
    backgroundColor = "#1e1e2e";
    textColor = "#cdd6f4";
    borderColor = "#89b4fa";
    borderRadius = 8;
    borderSize = 2;
    defaultTimeout = 5000;
    font = "Inter 11";
  };

  # Create screenshots directory
  home.file."Pictures/Screenshots/.keep".text = "";
}
