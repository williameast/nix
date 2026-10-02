# Waybar top bar
# Icons are written as Pango entities (&#x...;) so editors can't silently strip
# the private-use Nerd Font glyphs. Needs "Symbols Nerd Font Mono" (NixOS fonts).
{ config, pkgs, lib, osConfig, ... }:

let
  # Threads per host, for the per-core CPU sparkline
  cpuThreads = { orr = 16; yossarian = 8; }.${osConfig.networking.hostName} or 8;
  sparks = [ "&#x2581;" "&#x2582;" "&#x2583;" "&#x2584;" "&#x2585;" "&#x2586;" "&#x2587;" "&#x2588;" ];

  miloDashboard = "http://milo:8082";  # Homepage dashboard on milo

  powerMenu = pkgs.writeShellScriptBin "power-menu" ''
    choice=$(printf "Lock\nSuspend\nLogout\nReboot\nShutdown" | rofi -dmenu -i -p "Power" -theme-str 'window {width: 200px;} listview {lines: 5;}')
    case "$choice" in
      Lock)     swaylock -f ;;
      Suspend)  systemctl suspend ;;
      Logout)   hyprctl dispatch exit ;;
      Reboot)   systemctl reboot ;;
      Shutdown) systemctl poweroff ;;
    esac
  '';

  agendaNext = pkgs.writeShellScript "agenda-next" ''
    exec ${pkgs.python3}/bin/python3 ${./agenda-next.py} "${config.home.homeDirectory}/org"
  '';

  tailscaleStatus = pkgs.writeShellScript "tailscale-status" ''
    state=$(tailscale status --json 2>/dev/null | ${pkgs.jq}/bin/jq -r '.BackendState // "NoState"')
    if [ "$state" = "Running" ]; then
      echo '{"text": "ts", "class": "up"}'
    else
      echo '{"text": "ts", "class": "down"}'
    fi
  '';

  tailscaleToggle = pkgs.writeShellScript "tailscale-toggle" ''
    if tailscale status --json 2>/dev/null | ${pkgs.jq}/bin/jq -e '.BackendState == "Running"' >/dev/null; then
      tailscale down
    else
      tailscale up
    fi
    pkill -RTMIN+8 waybar
  '';

  miloStatus = pkgs.writeShellScript "milo-status" ''
    if ${pkgs.curl}/bin/curl -s -o /dev/null -m 3 ${miloDashboard}; then
      echo '{"text": "milo", "class": "up"}'
    else
      echo '{"text": "milo", "class": "down"}'
    fi
  '';

  # Middle-click on volume: cycle the default output between sinks
  cycleSink = pkgs.writeShellScript "cycle-sink" ''
    pactl=${pkgs.pulseaudio}/bin/pactl
    current=$($pactl get-default-sink)
    sinks=$($pactl list short sinks | cut -f2)
    next=$(printf '%s\n%s\n' "$sinks" "$sinks" | grep -A1 -x -F "$current" | sed -n 2p)
    [ -n "$next" ] && $pactl set-default-sink "$next"
  '';

  # swaync emits "0" when empty; hide the count in that case
  notifications = pkgs.writeShellScript "notifications" ''
    swaync-client -swb | ${pkgs.jq}/bin/jq --unbuffered -c \
      'if .text == "0" then .text = "" else .text = " " + .text end'
  '';

  terminal = cmd: "alacritty -e ${cmd}";

  bluetoothMenu = pkgs.writeShellScriptBin "bluetooth-menu" ''
    exec ${pkgs.rofi-bluetooth}/bin/rofi-bluetooth -i -theme menu
  '';
in
{
  home.packages = [ powerMenu bluetoothMenu pkgs.networkmanager_dmenu pkgs.btop ];

  # Menu theme: the launcher theme, a bit wider. A theme file rather than
  # -theme-str because rofi-bluetooth word-splits its arguments.
  xdg.dataFile."rofi/themes/menu.rasi".text = ''
    @import "custom"
    window { width: 420px; }
    listview { lines: 10; }
  '';

  # Wi-Fi menu: rofi, passwords prompted in rofi, status via swaync
  xdg.configFile."networkmanager-dmenu/config.ini".text = ''
    [dmenu]
    dmenu_command = rofi -dmenu -i -theme menu
    highlight = True
    compact = True
    wifi_chars = ▂▄▆█
    format = {name}  {sec}  {bars}
    list_saved = False
    prompt = Wi-Fi

    [dmenu_passphrase]
    obscure = True

    [editor]
    gui_if_available = True
    gui = nm-connection-editor

    [nmdm]
    rescan_delay = 5
    show_notifications = True
  '';

  programs.waybar = {
    enable = true;

    settings = [{
      layer = "top";
      position = "top";
      height = 30;
      margin-top = 6;
      margin-left = 10;
      margin-right = 10;
      spacing = 6;

      modules-left = [ "custom/logo" "hyprland/workspaces" "hyprland/window" ];
      modules-center = [ "mpris" "clock" "custom/agenda" ];
      modules-right = [ "group/sys" "group/net" "group/toggles" "group/io" "tray" "custom/power" ];

      "group/sys" = { orientation = "horizontal"; modules = [ "cpu" "memory" "temperature" "disk" ]; };
      "group/net" = { orientation = "horizontal"; modules = [ "custom/tailscale" "custom/milo" "network" ]; };
      "group/toggles" = { orientation = "horizontal"; modules = [ "idle_inhibitor" "custom/notification" ]; };
      "group/io" = { orientation = "horizontal"; modules = [ "privacy" "pulseaudio" "bluetooth" "hyprland/language" ]; };

      # ── Left ──
      "custom/logo" = {
        format = "&#xf313;";
        tooltip = false;
        on-click = "rofi -show drun";
      };

      "hyprland/workspaces" = {
        format = "{id}{windows}";
        on-click = "activate";
        persistent-workspaces = { "*" = 5; };
        window-rewrite-default = " &#xf2d0;";
        window-rewrite-separator = "";
        window-rewrite = {
          "class<firefox>" = " &#xf269;";
          "class<google-chrome>" = " &#xf268;";
          "class<Alacritty>" = " &#xf120;";
          "class<scratchterm>" = " &#xf120;";
          "class<[Ee]macs>" = " &#xe632;";
          "class<thunderbird>" = " &#xf0e0;";
          "class<thunar|Thunar>" = " &#xf07b;";
          "class<steam>" = " &#xf1b6;";
          "class<blender>" = " &#xf00ab;";
          "class<org.freecad.FreeCAD|FreeCAD>" = " &#xf0ad;";
          "class<zoom>" = " &#xf03d;";
          "class<resolve|org.kde.kdenlive|losslesscut>" = " &#xf03d;";
          "class<vlc>" = " &#xf144;";
          "class<org.keepassxc.KeePassXC>" = " &#xf084;";
        };
      };

      "hyprland/window" = {
        format = "{title}";
        icon = true;
        icon-size = 16;
        max-length = 50;
        separate-outputs = true;
      };

      # ── Center ──
      mpris = {
        format = "{status_icon} {dynamic}";
        format-stopped = "";
        dynamic-len = 40;
        dynamic-order = [ "artist" "title" ];
        status-icons = { playing = "&#xf04b;"; paused = "&#xf04c;"; };
        on-click = "play-pause";
        on-click-right = "next";
        on-click-middle = "previous";
        on-scroll-up = "next";
        on-scroll-down = "previous";
        tooltip = false;
      };

      clock = {
        format = "{:%a %d %b  %H:%M}";
        format-alt = "{:%A %d %B %Y  ·  week %V  ·  %H:%M:%S}";
        interval = 1;
        tooltip = false;
      };

      "custom/agenda" = {
        format = "&#xf073; {}";
        return-type = "json";
        exec = "${agendaNext}";
        interval = 60;
        on-click = "emacsclient -c --eval '(org-agenda-list)'";
        tooltip = false;
      };

      # ── System (cpu/memory always; temp/disk only when they matter) ──
      cpu = {
        format = "&#xf4bc; ${lib.concatMapStrings (i: "{icon${toString i}}") (lib.range 0 (cpuThreads - 1))} {usage}%";
        format-icons = sparks;
        interval = 2;
        states = { warning = 70; critical = 90; };
        on-click = terminal "btop";
        tooltip = false;
      };

      memory = {
        format = "&#xf538; {icon}";
        format-icons = [ "&#x25b1;&#x25b1;&#x25b1;&#x25b1;&#x25b1;" "&#x25b0;&#x25b1;&#x25b1;&#x25b1;&#x25b1;" "&#x25b0;&#x25b0;&#x25b1;&#x25b1;&#x25b1;"
                         "&#x25b0;&#x25b0;&#x25b0;&#x25b1;&#x25b1;" "&#x25b0;&#x25b0;&#x25b0;&#x25b0;&#x25b1;" "&#x25b0;&#x25b0;&#x25b0;&#x25b0;&#x25b0;" ];
        format-alt = "&#xf538; {used:0.1f}/{total:0.0f}G";
        interval = 5;
        states = { warning = 75; critical = 90; };
        tooltip = false;
      };

      temperature = {
        hwmon-path-abs = "/sys/devices/pci0000:00/0000:00:18.3/hwmon";
        input-filename = "temp1_input";
        format = "";  # hidden until it gets hot
        format-warning = "&#xf2c9; {temperatureC}°C";
        format-critical = "&#xf2c9; {temperatureC}°C";
        warning-threshold = 75;
        critical-threshold = 85;
        interval = 5;
        tooltip = false;
      };

      disk = {
        path = "/";
        format = "";  # hidden until the disk fills up
        format-warning = "&#xf0a0; {percentage_used}%";
        format-critical = "&#xf0a0; {percentage_used}%";
        states = { warning = 85; critical = 95; };
        interval = 60;
        tooltip = false;
      };

      # ── Network ──
      "custom/tailscale" = {
        format = "&#xf0582; {}";
        return-type = "json";
        exec = "${tailscaleStatus}";
        interval = 15;
        signal = 8;
        on-click = "${tailscaleToggle}";
        tooltip = false;
      };

      "custom/milo" = {
        format = "&#xf048b; {}";
        return-type = "json";
        exec = "${miloStatus}";
        interval = 30;
        on-click = "xdg-open ${miloDashboard}";
        tooltip = false;
      };

      network = {
        format-wifi = "&#xf1eb; {ipaddr}";
        format-ethernet = "&#xf0200; {ipaddr}";
        format-disconnected = "&#xf05aa; offline";
        interval = 5;
        on-click = "networkmanager_dmenu";
        on-click-right = "nm-connection-editor";  # advanced settings
        tooltip = false;
      };

      # ── Toggles ──
      idle_inhibitor = {
        format = "{icon}";
        format-icons = { activated = "&#xf0f4;"; deactivated = "&#xf06ca;"; };
        tooltip = false;
      };

      "custom/notification" = {
        format = "{icon}{text}";
        format-icons = {
          notification = "&#xf116b;";
          none = "&#xf0f3;";
          dnd-notification = "&#xf1f6;";
          dnd-none = "&#xf1f6;";
          inhibited-notification = "&#xf116b;";
          inhibited-none = "&#xf0f3;";
          dnd-inhibited-notification = "&#xf1f6;";
          dnd-inhibited-none = "&#xf1f6;";
        };
        return-type = "json";
        exec = "${notifications}";
        on-click = "swaync-client -t -sw";
        on-click-right = "swaync-client -d -sw";
        tooltip = false;
      };

      # ── I/O ──
      privacy = {
        icon-size = 14;
        modules = [ { type = "screenshare"; } { type = "audio-in"; } ];
      };

      pulseaudio = {
        format = "{icon} {volume}%";
        format-bluetooth = "&#xf025; {volume}%";
        format-muted = "&#xf0581; mute";
        format-icons = { headphone = "&#xf025;"; default = [ "&#xf026;" "&#xf027;" "&#xf028;" ]; };
        on-click = "pavucontrol";
        on-click-right = "wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle";
        on-click-middle = "${cycleSink}";
        scroll-step = 5;
        tooltip = false;
      };

      bluetooth = {
        format = "&#xf293;";
        format-connected = "&#xf00b1; {device_alias}";
        format-connected-battery = "&#xf00b1; {device_alias} {device_battery_percentage}%";
        format-disabled = "";
        format-off = "&#xf00b2;";
        on-click = "bluetooth-menu";
        on-click-right = "blueman-manager";  # advanced settings
        tooltip = false;
      };

      "hyprland/language" = {
        format = "{}";
        format-en = "GB";
        format-gb = "GB";
        format-de = "DE";
        tooltip = false;
      };

      tray = { spacing = 8; };

      "custom/power" = {
        format = "&#xf011;";
        on-click = "power-menu";
        tooltip = false;
      };
    }];

    style = ''
      @define-color bg       rgba(20, 17, 24, 0.88);
      @define-color pill     rgba(36, 28, 42, 0.92);
      @define-color edge     #3d2a42;
      @define-color fg       #c0b8c8;
      @define-color dim      #6e5f76;
      @define-color accent   #d4434a;
      @define-color warn     #e5a550;
      @define-color crit     #ff5555;
      @define-color ok       #7fb98a;

      * {
        font-family: "Inter", "Symbols Nerd Font Mono";
        font-size: 13px;
        min-height: 0;
        border: none;
        border-radius: 0;
      }

      window#waybar { background: transparent; color: @fg; }

      /* ── Pills ── */
      #custom-logo, #workspaces, #window, #mpris, #clock, #custom-agenda,
      #sys, #net, #toggles, #io, #tray, #custom-power {
        background: @pill;
        border: 1px solid @edge;
        border-radius: 10px;
        padding: 0 10px;
      }
      window#waybar.empty #window { background: transparent; border-color: transparent; }

      #cpu, #memory, #temperature, #disk, #custom-tailscale, #custom-milo, #network,
      #idle_inhibitor, #custom-notification, #privacy, #pulseaudio, #bluetooth, #language {
        padding: 0 6px;
      }

      /* ── Left ── */
      #custom-logo { color: @accent; font-size: 16px; padding: 0 12px 0 10px; }
      #custom-logo:hover { background: alpha(@accent, 0.18); }

      #workspaces { padding: 0 4px; }
      #workspaces button {
        color: @dim;
        padding: 0 7px;
        margin: 3px 1px;
        border-radius: 7px;
        transition: all 150ms ease;
      }
      #workspaces button.active { color: @bg; background: @accent; }
      #workspaces button.urgent { color: @crit; background: alpha(@crit, 0.2); }
      #workspaces button:hover { color: @fg; background: alpha(@fg, 0.08); }

      #window { color: @dim; }

      /* ── Center ── */
      #clock { color: @fg; font-weight: bold; }
      #mpris { color: @dim; }
      #mpris.playing { color: @fg; }
      #custom-agenda { color: @dim; }
      #custom-agenda.today { color: @fg; }
      #custom-agenda.soon { color: @warn; }
      #custom-agenda.now { color: @accent; animation: pulse 1.5s ease-in-out infinite alternate; }

      /* ── State colours: neutral until something needs attention ── */
      #cpu.warning, #memory.warning, #temperature.warning, #disk.warning { color: @warn; }
      #cpu.critical, #memory.critical, #temperature.critical, #disk.critical {
        color: @crit;
        animation: pulse 1s ease-in-out infinite alternate;
      }

      #custom-tailscale.up, #custom-milo.up { color: @ok; }
      #custom-tailscale.down, #custom-milo.down { color: @dim; }
      #network.disconnected { color: @crit; }

      #idle_inhibitor { color: @dim; }
      #idle_inhibitor.activated { color: @warn; }
      #custom-notification.notification { color: @accent; }
      #custom-notification.dnd-none, #custom-notification.dnd-notification { color: @dim; }

      #privacy-item { color: @crit; padding: 0 4px; }
      #pulseaudio.muted, #bluetooth.off { color: @dim; }
      #bluetooth.connected { color: @fg; }
      #language { color: @dim; }

      #custom-power { color: @accent; padding: 0 12px; }
      #custom-power:hover { color: @bg; background: @accent; }

      #tray > .passive { -gtk-icon-effect: dim; }
      #tray > .needs-attention { -gtk-icon-effect: highlight; }

      /* Hover feedback for everything clickable */
      #cpu:hover, #memory:hover, #clock:hover, #custom-agenda:hover, #mpris:hover,
      #custom-tailscale:hover, #custom-milo:hover, #network:hover, #idle_inhibitor:hover,
      #custom-notification:hover, #pulseaudio:hover, #bluetooth:hover {
        background: alpha(@fg, 0.08);
        border-radius: 8px;
      }

      @keyframes pulse { to { opacity: 0.45; } }
    '';
  };
}
