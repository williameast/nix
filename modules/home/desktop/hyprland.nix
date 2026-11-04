# Hyprland compositor configuration
{ config, pkgs, lib, osConfig, ... }:

let
  # Lock screen look, mimicking tuigreet on the Linux console
  tg = {
    bg = "rgb(000000)";
    fg = "rgb(cccccc)";
    dim = "rgb(888888)";
    font = "JetBrains Mono";
    size = 14;     # ~11px per character
    left = -210;   # inner left edge of the box, relative to screen centre
  };
in
{
  home.packages = with pkgs; [
    hyprpaper            # Wallpaper daemon
    grim                 # Screenshot tool
    slurp                # Region selector
    wl-clipboard         # Clipboard utilities
    satty                # Screenshot annotation (Shift+F10)
    rofimoji             # Emoji picker (Super+;)
    wtype                # lets rofimoji type into the focused window
    google-chrome        # Browser
    pavucontrol          # Volume control GUI (click from waybar)
    alsa-scarlett-gui    # Focusrite Scarlett Gen 3+ mixer/routing
    networkmanagerapplet # nm-connection-editor (advanced network settings)
    # Power menu is handled via rofi (see keybind Super+X)
    # File manager
    thunar
    thunar-archive-plugin
    thunar-volman
    file-roller  # Archive GUI + backend for thunar-archive-plugin
    unzip        # CLI zip extraction
    zip          # CLI zip creation
  ];

  # Hyprland compositor
  wayland.windowManager.hyprland = {
    enable = true;
    configType = "hyprlang";

    settings = {
      # ── Monitors ──
      monitor = [ ",preferred,auto,1" ];

      # ── Input ──
      input = {
        kb_layout = "gb,de";
        kb_options = "caps:escape,grp:win_space_toggle";

        touchpad = {
          tap-to-click = true;
          natural_scroll = true;
          scroll_factor = 0.3;
        };

        sensitivity = 0.3;
        follow_mouse = 1;
      };

      # ── General ──
      general = {
        gaps_in = 4;
        gaps_out = 8;
        border_size = 2;
        "col.active_border" = "rgb(d4434a)";
        "col.inactive_border" = "rgb(45475a)";
        layout = "dwindle";
      };

      # ── Decoration ──
      decoration = {
        rounding = 8;

        blur = {
          enabled = true;
          size = 6;
          passes = 2;
          new_optimizations = true;
        };

        shadow = {
          enabled = true;
          range = 12;
          render_power = 2;
          color = "rgba(00000044)";
        };
      };

      # ── Animations ──
      animations = {
        enabled = true;

        bezier = [
          "easeOut, 0.16, 1, 0.3, 1"
          "overshoot, 0.05, 0.9, 0.1, 1.05"
          "smooth, 0.25, 0.1, 0.25, 1"
        ];

        animation = [
          "windows, 1, 5, overshoot, popin 80%"
          "windowsOut, 1, 5, easeOut, popin 80%"
          "windowsMove, 1, 4, smooth"
          "fade, 1, 4, smooth"
          "fadeDim, 1, 4, smooth"
          "workspaces, 1, 5, overshoot, slide"
          "border, 1, 4, smooth"
          "borderangle, 1, 30, smooth, loop"
          "layers, 1, 3, smooth, fade"
        ];
      };

      # ── Layout ──
      dwindle = {
        preserve_split = true;
      };

      # ── Misc ──
      misc = {
        force_default_wallpaper = 0;
        disable_hyprland_logo = true;
        background_color = "rgb(141118)";
        mouse_move_enables_dpms = true;
        key_press_enables_dpms = true;
      };

      # ── XWayland ──
      xwayland = {
        force_zero_scaling = true;
      };

      # ── Environment variables ──
      env = [
        "QT_QPA_PLATFORM,wayland"
        "QT_QPA_PLATFORMTHEME,xdgdesktopportal"
        "MOZ_ENABLE_WAYLAND,1"
        "NIXOS_OZONE_WL,1"
        "XCURSOR_THEME,Adwaita"
        "XCURSOR_SIZE,24"
      ];

      # ── Autostart ──
      exec-once = [
        "${pkgs.writeShellScript "start-hyprpaper" ''
          hyprpaper &
          sleep 1
          hyprctl hyprpaper preload ~/.config/hypr/wallpaper.jpg
          hyprctl hyprpaper wallpaper ,~/.config/hypr/wallpaper.jpg
        ''}"
        "waybar"
        "swaync"
        "blueman-applet"  # pairing agent only (tray icon disabled below)
      ];

      # ── Keybindings ──
      "$mod" = "SUPER";

      bind = [
        # Launch apps
        "$mod, Return, exec, alacritty"
        "$mod, D, exec, rofi -show drun"
        "$mod, E, exec, emacsclient -c -a emacs"
        "$mod, B, exec, firefox"
        "$mod, M, exec, thunderbird"
        "$mod, T, exec, thunar"
        "$mod, Q, killactive"

        # Screenshots (saved to file AND copied to clipboard)
        ", F10, exec, ${pkgs.writeShellScript "screenshot-region" ''
          f=~/Pictures/Screenshots/screenshot-$(date +%Y-%m-%d_%H-%M-%S).png
          grim -g "$(slurp)" "$f" && wl-copy < "$f"
        ''}"
        "$mod, F10, exec, ${pkgs.writeShellScript "screenshot-screen" ''
          f=~/Pictures/Screenshots/screenshot-$(date +%Y-%m-%d_%H-%M-%S).png
          grim "$f" && wl-copy < "$f"
        ''}"
        # Region, then annotate in satty (Ctrl+S saves, Enter copies)
        "SHIFT, F10, exec, ${pkgs.writeShellScript "screenshot-annotate" ''
          grim -g "$(slurp)" - | satty --filename - \
            --output-filename ~/Pictures/Screenshots/screenshot-$(date +%Y-%m-%d_%H-%M-%S)-annotated.png \
            --copy-command wl-copy --early-exit
        ''}"
        "$mod SHIFT, F10, exec, ${pkgs.writeShellScript "screenshot-window" ''
          f=~/Pictures/Screenshots/screenshot-$(date +%Y-%m-%d_%H-%M-%S).png
          grim -g "$(hyprctl activewindow -j | ${pkgs.jq}/bin/jq -r '"\(.at[0]),\(.at[1]) \(.size[0])x\(.size[1])"')" "$f" && wl-copy < "$f"
        ''}"

        # Focus movement (vim keys)
        "$mod, H, movefocus, l"
        "$mod, L, movefocus, r"
        "$mod, J, movefocus, d"
        "$mod, K, movefocus, u"

        # Focus movement (arrow keys)
        "$mod, Left, movefocus, l"
        "$mod, Right, movefocus, r"
        "$mod, Down, movefocus, d"
        "$mod, Up, movefocus, u"

        # Move windows (vim keys)
        "$mod SHIFT, H, movewindow, l"
        "$mod SHIFT, L, movewindow, r"
        "$mod SHIFT, J, movewindow, d"
        "$mod SHIFT, K, movewindow, u"

        # Move windows (arrow keys)
        "$mod SHIFT, Left, movewindow, l"
        "$mod SHIFT, Right, movewindow, r"
        "$mod SHIFT, Down, movewindow, d"
        "$mod SHIFT, Up, movewindow, u"

        # Fullscreen
        "$mod, F, fullscreen, 1"
        "$mod SHIFT, F, fullscreen, 0"

        # Toggle floating / split
        "$mod, V, togglefloating"

        # Resize mode: Mod+R enters, hjkl/arrows resize, Escape/Return exits
        "$mod, R, submap, resize"

        # Workspaces
        "$mod, 1, workspace, 1"
        "$mod, 2, workspace, 2"
        "$mod, 3, workspace, 3"
        "$mod, 4, workspace, 4"
        "$mod, 5, workspace, 5"
        "$mod, 6, workspace, 6"
        "$mod, 7, workspace, 7"
        "$mod, 8, workspace, 8"
        "$mod, 9, workspace, 9"

        # Move window to workspace
        "$mod SHIFT, 1, movetoworkspace, 1"
        "$mod SHIFT, 2, movetoworkspace, 2"
        "$mod SHIFT, 3, movetoworkspace, 3"
        "$mod SHIFT, 4, movetoworkspace, 4"
        "$mod SHIFT, 5, movetoworkspace, 5"
        "$mod SHIFT, 6, movetoworkspace, 6"
        "$mod SHIFT, 7, movetoworkspace, 7"
        "$mod SHIFT, 8, movetoworkspace, 8"
        "$mod SHIFT, 9, movetoworkspace, 9"

        # Monitor movement
        "$mod, comma, focusmonitor, l"
        "$mod, period, focusmonitor, r"
        "$mod SHIFT, comma, movewindow, mon:l"
        "$mod SHIFT, period, movewindow, mon:r"

        # Dropdown scratchpad terminal (respawns if closed)
        "$mod, S, exec, ${pkgs.writeShellScript "scratchpad-toggle" ''
          if hyprctl clients -j | ${pkgs.jq}/bin/jq -e '[.[] | select(.class == "scratchterm")] | length > 0' > /dev/null 2>&1; then
            hyprctl dispatch togglespecialworkspace scratchpad
          else
            hyprctl dispatch exec '[workspace special:scratchpad] alacritty --class scratchterm'
            sleep 0.3
            hyprctl dispatch togglespecialworkspace scratchpad
          fi
        ''}"

        # Clipboard history, emoji, calculator (rofi)
        "$mod, C, exec, cliphist list | rofi -dmenu -i -p Clipboard -theme menu -display-columns 2 | cliphist decode | wl-copy"
        "$mod, semicolon, exec, rofimoji --selector-args='-theme menu'"
        "$mod, equal, exec, rofi -show calc -modi calc -no-show-match -no-sort -theme menu"

        # Notification center
        "$mod, N, exec, swaync-client -t -sw"

        # Power menu (rofi)
        "$mod, X, exec, power-menu"

        # Wi-Fi / Bluetooth menus (rofi)
        "$mod, W, exec, network-menu"
        "$mod SHIFT, B, exec, bluetooth-menu"

        # Alt-Tab window cycling
        "ALT, Tab, cyclenext"
        "ALT SHIFT, Tab, cyclenext, prev"

        # Lock screen
        "$mod, Escape, exec, loginctl lock-session"

        # Exit Hyprland
        "$mod SHIFT, E, exit"
      ];

      # Volume and media keys (work without mod, repeatable)
      binde = [
        ", XF86AudioRaiseVolume, exec, wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%+"
        ", XF86AudioLowerVolume, exec, wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%-"
      ];
      bindl = [
        ", XF86AudioMute, exec, wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle"
        ", XF86AudioPlay, exec, ${pkgs.playerctl}/bin/playerctl play-pause"
        ", XF86AudioNext, exec, ${pkgs.playerctl}/bin/playerctl next"
        ", XF86AudioPrev, exec, ${pkgs.playerctl}/bin/playerctl previous"
      ];

      # Mouse binds (move/resize with Mod+drag)
      bindm = [
        "$mod, mouse:272, movewindow"
        "$mod, mouse:273, resizewindow"
      ];

    };

    # Resize submap and window rules (raw hyprlang)
    extraConfig = ''
      submap = resize
      binde = , H, resizeactive, -30 0
      binde = , L, resizeactive, 30 0
      binde = , K, resizeactive, 0 -30
      binde = , J, resizeactive, 0 30
      binde = , Left, resizeactive, -30 0
      binde = , Right, resizeactive, 30 0
      binde = , Up, resizeactive, 0 -30
      binde = , Down, resizeactive, 0 30
      bind = , Escape, submap, reset
      bind = , Return, submap, reset
      submap = reset

      # Scratchpad terminal: float, 75% width, 50% height, centered
      windowrule {
        name = scratchpad-float
        match:class = (scratchterm)
        float = on
        size = 75% 50%
        move = 12.5% 5%
        animation = slide
      }
    '';
  };

  # Waybar lives in waybar.nix

  # ── SwayNotificationCenter (replaces mako) ──
  services.swaync = {
    enable = true;
    settings = {
      positionX = "right";
      positionY = "top";
      control-center-width = 400;
      notification-window-width = 400;
      notification-icon-size = 48;
      notification-body-image-height = 100;
      notification-body-image-width = 200;
      timeout = 5;
      timeout-low = 3;
      timeout-critical = 0;
      fit-to-screen = true;
      keyboard-shortcuts = true;
      image-visibility = "when-available";
      transition-time = 200;
      hide-on-clear = false;
      hide-on-action = true;
      script-fail-notify = true;
    };
    style = ''
      * {
        font-family: "Inter", "Font Awesome 6 Free";
        font-size: 13px;
      }

      .notification-row {
        outline: none;
      }

      .notification {
        border-radius: 8px;
        margin: 4px 8px;
        padding: 0;
        border: 2px solid #3d2a42;
        background-color: #141118;
        color: #c0b8c8;
      }

      .notification-content {
        padding: 8px;
      }

      .close-button {
        background: #3d2a42;
        color: #c0b8c8;
        text-shadow: none;
        border-radius: 50%;
        margin: 4px;
        padding: 2px;
      }

      .close-button:hover {
        background: #5a3a50;
      }

      .notification-default-action,
      .notification-action {
        border-radius: 8px;
        background: transparent;
        color: #cdd6f4;
        padding: 4px;
        margin: 0;
        border: none;
      }

      .notification-default-action:hover,
      .notification-action:hover {
        background: #3d2a42;
      }

      .notification-group-headers {
        color: #7a6880;
        font-weight: bold;
        margin: 4px 8px;
      }

      .body-image {
        margin-top: 4px;
        border-radius: 8px;
      }

      .summary {
        font-weight: bold;
        color: #c0b8c8;
      }

      .body {
        color: #8a7a90;
      }

      .control-center {
        background-color: rgba(20, 17, 24, 0.95);
        border-radius: 12px;
        border: 2px solid #3d2a42;
        margin: 8px;
        padding: 12px;
      }

      .control-center-list {
        background: transparent;
      }

      .control-center .notification {
        background-color: #1a1520;
      }

      .widget-title {
        color: #d4434a;
        font-weight: bold;
        margin: 4px 0;
      }

      .widget-title > button {
        color: #e06c75;
        background: transparent;
        border: 1px solid #3d2a42;
        border-radius: 8px;
        padding: 4px 8px;
      }

      .widget-title > button:hover {
        background: #3d2a42;
      }

      .widget-dnd {
        color: #c0b8c8;
        margin: 4px 0;
      }

      .widget-dnd > switch {
        background: #3d2a42;
        border-radius: 12px;
      }

      .widget-dnd > switch:checked {
        background: #d4434a;
      }

      .widget-dnd > switch slider {
        background: #c0b8c8;
        border-radius: 50%;
      }
    '';
  };

  # Terminal with transparency
  programs.alacritty = {
    enable = true;
    settings = {
      window = {
        opacity = 0.85;
        padding = { x = 8; y = 8; };
      };
      font = {
        normal.family = "JetBrains Mono";
        size = 12;
      };
    };
  };

  # GTK theme and icons
  gtk = {
    enable = true;
    gtk4.theme = null;
    theme = {
      name = "Adwaita-dark";
      package = pkgs.gnome-themes-extra;
    };
    iconTheme = {
      name = "Papirus-Dark";
      package = pkgs.papirus-icon-theme;
    };
    cursorTheme = {
      name = "Adwaita";
      size = 24;
    };
  };

  # Qt theme (for KeePassXC and other Qt apps)
  qt = {
    enable = true;
    platformTheme.name = "adwaita";
    style = {
      name = "adwaita-dark";
      package = pkgs.adwaita-qt;
    };
  };

  # Lock screen: hyprlock dressed up as tuigreet, with the user prefilled
  programs.hyprlock = {
    enable = true;
    settings = {
      general = {
        hide_cursor = true;
        ignore_empty_input = true;
        text_trim = false;
      };

      background = [{ color = tg.bg; }];

      # The box, then a black strip that cuts the title into its top border
      shape = [
        {
          size = "480, 140";
          color = "rgba(00000000)";
          rounding = 0;
          border_size = 1;
          border_color = tg.fg;
          position = "0, 0";
          halign = "center";
          valign = "center";
        }
        {
          size = "270, 20";
          color = tg.bg;
          rounding = 0;
          position = "0, 70";
          halign = "center";
          valign = "center";
        }
      ];

      label = [
        {
          # tuigreet --time
          text = ''cmd[update:1000] date "+%a, %d %b %Y %H:%M:%S"'';
          color = tg.fg;
          font_family = tg.font;
          font_size = tg.size;
          position = "0, -16";
          halign = "center";
          valign = "top";
        }
        {
          text = " Authenticate into ${osConfig.networking.hostName} ";
          color = tg.fg;
          font_family = tg.font;
          font_size = tg.size;
          position = "0, 70";
          halign = "center";
          valign = "center";
        }
        {
          # Labels are positioned by their centre: left edge + half their width
          text = "Username: ${config.home.username}";
          color = tg.fg;
          font_family = tg.font;
          font_size = tg.size;
          position = "${toString (tg.left + 84)}, 20";
          halign = "center";
          valign = "center";
        }
        {
          text = "Password:";
          color = tg.fg;
          font_family = tg.font;
          font_size = tg.size;
          position = "${toString (tg.left + 50)}, -20";
          halign = "center";
          valign = "center";
        }
      ];

      # Bare field (no outline or fill): asterisks right after "Password: "
      input-field = [{
        size = "300, 30";
        position = "${toString (tg.left + 112 + 150)}, -20";
        halign = "center";
        valign = "center";
        outline_thickness = 0;
        rounding = 0;
        inner_color = "rgba(00000000)";
        outer_color = "rgba(00000000)";
        check_color = "rgba(00000000)";
        fail_color = "rgba(00000000)";
        capslock_color = "rgba(00000000)";
        font_color = tg.fg;
        font_family = tg.font;
        dots_text_format = "*";
        dots_size = 0.5;
        dots_spacing = 0.15;
        dots_center = false;
        fade_on_empty = false;
        placeholder_text = "";
        fail_text = "$FAIL";
      }];
    };
  };

  # Authentication popups for apps that need admin rights (pkexec, etc.)
  services.hyprpolkitagent.enable = true;

  # Clipboard history, browsed with Super+C
  services.cliphist.enable = true;

  # Warmer screen in the evening
  services.hyprsunset = {
    enable = true;
    settings.profile = [
      { time = "7:00";  identity = true; }
      { time = "20:30"; temperature = 4000; }
      { time = "22:30"; temperature = 3400; }
    ];
  };

  # Idle management - lock at 5min, screen off at 5.5min, suspend at 30min.
  # hypridle rather than swayidle: hyprlock only exits on unlock, which would
  # stall swayidle's before-sleep hook and with it the suspend.
  services.hypridle = {
    enable = true;
    settings = {
      general = {
        lock_cmd = "pidof hyprlock || hyprlock";
        before_sleep_cmd = "loginctl lock-session";
        after_sleep_cmd = "hyprctl dispatch dpms on";
      };
      listener = [
        { timeout = 300;  on-timeout = "loginctl lock-session"; }
        { timeout = 330;  on-timeout = "hyprctl dispatch dpms off"; on-resume = "hyprctl dispatch dpms on"; }
        { timeout = 1800; on-timeout = "systemctl suspend"; }
      ];
    };
  };

  # Wallpaper
  home.file.".config/hypr/wallpaper.jpg".source = ../../../assets/desktop.JPG;
  xdg.configFile."hypr/hyprpaper.conf".text = let
    wp = "${config.home.homeDirectory}/.config/hypr/wallpaper.jpg";
  in ''
    preload = ${wp}
    wallpaper = ,${wp}
    splash = false
  '';

  # Create screenshots directory
  home.file."Pictures/Screenshots/.keep".text = "";

  # blueman-applet stays running as the Bluetooth pairing agent (PIN prompts),
  # but the bar's Bluetooth module replaces its tray icon
  dconf.settings."org/blueman/general".plugin-list = [ "!StatusIcon" ];
}
