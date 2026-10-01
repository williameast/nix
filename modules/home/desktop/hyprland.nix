# Hyprland compositor configuration
{ config, pkgs, lib, ... }:

{
  home.packages = with pkgs; [
    hyprpaper            # Wallpaper daemon
    swaylock             # Screen locker
    grim                 # Screenshot tool
    slurp                # Region selector
    wl-clipboard         # Clipboard utilities
    google-chrome        # Browser
    pavucontrol          # Volume control GUI (click from waybar)
    networkmanagerapplet # nm-applet tray (wifi management)
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
        "nm-applet --indicator"
        "blueman-applet"
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
        ", Print, exec, ${pkgs.writeShellScript "screenshot-region" ''
          f=~/Pictures/Screenshots/screenshot-$(date +%Y-%m-%d_%H-%M-%S).png
          grim -g "$(slurp)" "$f" && wl-copy < "$f"
        ''}"
        "$mod, Print, exec, ${pkgs.writeShellScript "screenshot-screen" ''
          f=~/Pictures/Screenshots/screenshot-$(date +%Y-%m-%d_%H-%M-%S).png
          grim "$f" && wl-copy < "$f"
        ''}"
        "$mod SHIFT, Print, exec, ${pkgs.writeShellScript "screenshot-window" ''
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

        # Notification center
        "$mod, N, exec, swaync-client -t -sw"

        # Power menu (rofi)
        "$mod, X, exec, ${pkgs.writeShellScript "rofi-power" ''
          choice=$(printf "Lock\nSuspend\nLogout\nReboot\nShutdown" | rofi -dmenu -i -p "Power" -theme-str 'window {width: 200px;} listview {lines: 5;}')
          case "$choice" in
            Lock)     swaylock -f ;;
            Suspend)  systemctl suspend ;;
            Logout)   hyprctl dispatch exit ;;
            Reboot)   systemctl reboot ;;
            Shutdown) systemctl poweroff ;;
          esac
        ''}"

        # Alt-Tab window cycling
        "ALT, Tab, cyclenext"
        "ALT SHIFT, Tab, cyclenext, prev"

        # Lock screen
        "$mod, Escape, exec, swaylock"

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

  # ── Waybar ──
  programs.waybar = {
    enable = true;

    settings = [{
      layer = "top";
      position = "top";
      height = 28;
      spacing = 0;

      modules-left = [ "custom/logo" "hyprland/workspaces" "hyprland/window" ];
      modules-center = [ "clock" ];
      modules-right = [
        "custom/notification"
        "cpu"
        "memory"
        "temperature"
        "disk"
        "pulseaudio"
        "bluetooth"
        "network"
        "hyprland/language"
        "tray"
        "custom/power"
      ];

      "custom/logo" = {
        format = " ";
        tooltip = false;
      };

      "hyprland/workspaces" = {
        format = "{id}";
        on-click = "activate";
        persistent-workspaces = { "*" = 5; };
      };

      "hyprland/window" = {
        max-length = 40;
        format = "{}";
        rewrite = { "" = "Desktop"; };
      };

      "hyprland/language" = {
        format = " {}";
        format-en = "EN";
        format-gb = "GB";
        format-de = "DE";
      };

      cpu = {
        format = " {usage}%";
        interval = 3;
        tooltip-format = "CPU: {usage}% @ {avg_frequency}GHz\n{cores} cores";
      };

      memory = {
        format = " {percentage}%";
        format-alt = " {used:0.1f}G/{total:0.1f}G";
        interval = 5;
        tooltip-format = "RAM: {used:0.1f}GiB / {total:0.1f}GiB ({percentage}%)\nSwap: {swapUsed:0.1f}GiB / {swapTotal:0.1f}GiB";
      };

      temperature = {
        format = " {temperatureC}°C";
        critical-threshold = 85;
        format-critical = " {temperatureC}°C";
        interval = 5;
      };

      disk = {
        format = " {percentage_used}%";
        path = "/";
        interval = 30;
        tooltip-format = "Disk: {used} / {total} ({percentage_used}%)";
      };

      clock = {
        format = " {:%H:%M}";
        format-alt = " {:%A, %d %B %Y  %H:%M:%S}";
        tooltip-format = "<tt>{calendar}</tt>";
        interval = 1;
      };

      bluetooth = {
        format = " {status}";
        format-connected = " {device_alias}";
        format-connected-battery = " {device_alias} {device_battery_percentage}%";
        format-disabled = "";
        format-off = "";
        tooltip-format = "{controller_alias}\t{controller_address}\n{num_connections} connected";
        tooltip-format-connected = "{controller_alias}\t{controller_address}\n{num_connections} connected\n\n{device_enumerate}";
        tooltip-format-enumerate-connected = "{device_alias}\t{device_address}";
        tooltip-format-enumerate-connected-battery = "{device_alias}\t{device_address}\t{device_battery_percentage}%";
        on-click = "blueman-manager";
      };

      network = {
        format-wifi = " {essid} {signalStrength}%";
        format-ethernet = " {ipaddr}";
        format-disconnected = " down";
        tooltip-format = "{ifname}: {ipaddr}/{cidr}\n {bandwidthUpBits}  {bandwidthDownBits}";
        interval = 5;
        on-click = "nm-connection-editor";
      };

      pulseaudio = {
        format = "{icon} {volume}%";
        format-muted = " mute";
        format-icons = {
          default = [ "" "" "" ];
        };
        on-click = "pavucontrol";
        on-click-right = "wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle";
        scroll-step = 5;
      };

      "custom/notification" = {
        tooltip = false;
        format = "{icon} {}";
        format-icons = {
          notification = "";
          none = "";
          dnd-notification = "";
          dnd-none = "";
          inhibited-notification = "";
          inhibited-none = "";
          dnd-inhibited-notification = "";
          dnd-inhibited-none = "";
        };
        return-type = "json";
        exec = "swaync-client -swb";
        on-click = "swaync-client -t -sw";
        on-click-right = "swaync-client -d -sw";
        escape = true;
      };

      "custom/power" = {
        format = "";
        tooltip = false;
        on-click = "${pkgs.writeShellScript "rofi-power" ''
          choice=$(printf "Lock\nSuspend\nLogout\nReboot\nShutdown" | rofi -dmenu -i -p "Power" -theme-str 'window {width: 200px;} listview {lines: 5;}')
          case "$choice" in
            Lock)     swaylock -f ;;
            Suspend)  systemctl suspend ;;
            Logout)   hyprctl dispatch exit ;;
            Reboot)   systemctl reboot ;;
            Shutdown) systemctl poweroff ;;
          esac
        ''}";
      };

      tray = {
        spacing = 8;
      };
    }];

    style = ''
      * {
        font-family: "JetBrains Mono", "Font Awesome 6 Free";
        font-size: 12px;
        min-height: 0;
      }

      window#waybar {
        background-color: rgba(20, 17, 24, 0.95);
        color: #c0b8c8;
        border-bottom: 1px solid #3d2a42;
      }

      /* ── Logo ── */
      #custom-logo {
        color: #d4434a;
        font-size: 15px;
        padding: 0 10px 0 8px;
      }

      /* ── Workspaces ── */
      #workspaces button {
        padding: 0 6px;
        color: #584960;
        border-bottom: 2px solid transparent;
        border-radius: 0;
        margin: 0 1px;
      }

      #workspaces button.active {
        color: #d4434a;
        border-bottom: 2px solid #d4434a;
        background: rgba(212, 67, 74, 0.1);
      }

      #workspaces button.urgent {
        color: #e06c75;
        background: rgba(224, 108, 117, 0.2);
      }

      #workspaces button:hover {
        background: rgba(90, 60, 100, 0.3);
        color: #c0b8c8;
      }

      /* ── Window title ── */
      #window {
        color: #7a6880;
        font-style: italic;
        padding: 0 12px;
      }

      /* ── Clock ── */
      #clock {
        color: #d4434a;
        font-weight: bold;
        padding: 0 12px;
      }

      /* ── Common module styling ── */
      #cpu, #memory, #temperature, #disk, #pulseaudio, #bluetooth, #network,
      #tray, #language, #custom-notification, #custom-power {
        padding: 0 8px;
      }

      /* ── Notifications ── */
      #custom-notification {
        color: #e06c75;
        padding: 0 10px;
      }

      /* ── System monitors ── */
      #cpu {
        color: #cc6666;
      }

      #memory {
        color: #c97b4a;
      }

      #temperature {
        color: #b87333;
      }

      #temperature.critical {
        color: #ff4444;
        animation: blink 0.5s alternate infinite;
      }

      #disk {
        color: #8a6576;
      }

      /* ── Audio ── */
      #pulseaudio {
        color: #a85070;
      }

      #pulseaudio.muted {
        color: #504050;
      }

      /* ── Bluetooth ── */
      #bluetooth {
        color: #8a5070;
      }

      #bluetooth.disabled, #bluetooth.off {
        color: #403040;
      }

      /* ── Network ── */
      #network {
        color: #7a6070;
      }

      #network.disconnected {
        color: #cc4444;
      }

      /* ── Language ── */
      #language {
        color: #6a5a6a;
      }

      /* ── Power ── */
      #custom-power {
        color: #d4434a;
        padding: 0 12px 0 8px;
      }

      #custom-power:hover {
        color: #ff5555;
        background: rgba(212, 67, 74, 0.15);
      }

      /* ── Tray ── */
      #tray > .passive {
        -gtk-icon-effect: dim;
      }

      /* ── Separators between modules ── */
      #cpu, #memory, #temperature, #disk, #pulseaudio, #bluetooth, #network, #language {
        border-right: 1px solid rgba(80, 50, 70, 0.4);
        margin-right: 1px;
      }

      /* ── Tooltip ── */
      tooltip {
        background: #141118;
        border: 1px solid #3d2a42;
        border-radius: 6px;
      }

      tooltip label {
        color: #c0b8c8;
      }

      @keyframes blink {
        to { color: #ff0000; }
      }
    '';
  };

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
    ring-ver-color=d4434a
    inside-ver-color=1e1e2e
    ring-wrong-color=ff5555
    inside-wrong-color=1e1e2e
  '';

  # Idle management - lock at 5min, screen off at 5.5min, suspend at 30min
  services.swayidle = {
    enable = true;
    events = {
      before-sleep = "${pkgs.swaylock}/bin/swaylock -f";
      after-resume = "hyprctl dispatch dpms on";
    };
    timeouts = [
      { timeout = 300;  command = "${pkgs.swaylock}/bin/swaylock -f"; }
      { timeout = 330;  command = "hyprctl dispatch dpms off"; }
      { timeout = 1800; command = "systemctl suspend"; }
    ];
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
}
