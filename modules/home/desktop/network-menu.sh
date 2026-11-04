# Network menu: Ethernet, Wi-Fi networks, Tailscale and settings in one rofi list,
# with the current connection shown above it. Wrapped by writeShellApplication
# in waybar.nix (runtime inputs, strict mode, shellcheck).

ICON_ETH=$'\U000f0200'
ICON_WIFI=$''
ICON_WIFI_OFF=$'\U000f05aa'
ICON_LOCK=$''
ICON_RESCAN=$''
ICON_VPN=$'\U000f0582'
ICON_SETTINGS=$''

rofi_menu() { rofi -dmenu -i -theme menu -markup-rows "$@"; }
notify() { notify-send -a Network -i network-wireless "$@" || true; }
esc() { sed 's/&/\&amp;/g; s/</\&lt;/g; s/>/\&gt;/g'; }
dim() { printf '<span alpha="45%%">%s</span>' "$1"; }

bars() {
  local s=$1 on n
  if   (( s >= 75 )); then n=4
  elif (( s >= 50 )); then n=3
  elif (( s >= 25 )); then n=2
  else n=1; fi
  on=${BARS:0:n}
  printf '%s%s' "$on" "$(dim "${BARS:n}")"
}
BARS="▂▄▆█"

device_of() { nmcli -t -f DEVICE,TYPE device | awk -F: -v t="$1" '$2 == t { print $1; exit }'; }
wifi_dev=$(device_of wifi)
eth_dev=$(device_of ethernet)

# Saved Wi-Fi profiles (profile name is the SSID unless renamed by hand)
saved=$(nmcli -t -f NAME,TYPE connection show | awk -F: '$2 == "802-11-wireless" { print $1 }')
is_saved() { printf '%s\n' "$saved" | grep -qxF -- "$1"; }

# ── Status line ──
status=$(nmcli -t -f TYPE,NAME,DEVICE connection show --active \
  | awk -F: '$1 == "802-3-ethernet" { print "Ethernet (" $3 ")"; exit }
             $1 == "802-11-wireless" { $1 = $3 = ""; sub(/^ +/, ""); sub(/ +$/, ""); print "Wi-Fi: " $0; exit }')
ip=$(ip -4 route get 1.1.1.1 2>/dev/null | awk '{ for (i = 1; i < NF; i++) if ($i == "src") print $(i + 1) }')
if [ -n "$status" ]; then
  mesg="Connected via $(esc <<<"$status")${ip:+  ·  $ip}"
else
  mesg="Offline"
fi

# ── Rows: parallel arrays of action and label ──
actions=()
labels=()
add() { actions+=("$1"); labels+=("$2"); }

if [ -n "$eth_dev" ]; then
  case "$(nmcli -t -g GENERAL.STATE device show "$eth_dev")" in
    100*) add eth-down "$ICON_ETH  <b>Ethernet</b>  $(dim 'connected · click to disconnect')" ;;
    20*)  add none     "$ICON_ETH  Ethernet  $(dim 'cable unplugged')" ;;
    *)    add eth-up   "$ICON_ETH  Ethernet  $(dim 'click to connect')" ;;
  esac
fi

wifi_on=false
[ -n "$wifi_dev" ] && [ "$(nmcli radio wifi)" = enabled ] && wifi_on=true

if $wifi_on; then
  # Strongest access point per SSID; SSID last so escaped colons stay in it
  while IFS=: read -r inuse signal security ssid; do
    ssid=${ssid//\\:/:}
    [ -z "$ssid" ] && continue
    lock=""
    [ -n "$security" ] && [ "$security" != "--" ] && lock="  $(dim "$ICON_LOCK")"
    note=""
    is_saved "$ssid" && note="  $(dim saved)"
    if [ "$inuse" = "*" ]; then
      add "active:$ssid" "$(bars "$signal")  <b>$(esc <<<"$ssid")</b>$lock  $(dim connected)"
    else
      add "wifi:$security:$ssid" "$(bars "$signal")  $(esc <<<"$ssid")$lock$note"
    fi
  done < <(nmcli -t -f IN-USE,SIGNAL,SECURITY,SSID device wifi list --rescan auto \
             | sort -t: -k2,2nr \
             | awk '{ s = $0; for (i = 0; i < 3; i++) s = substr(s, index(s, ":") + 1) } !seen[s]++')
  add rescan   "$ICON_RESCAN  Rescan Wi-Fi"
  add wifi-off "$ICON_WIFI_OFF  Turn Wi-Fi off"
elif [ -n "$wifi_dev" ]; then
  add wifi-on  "$ICON_WIFI  Turn Wi-Fi on"
fi

if command -v tailscale >/dev/null; then
  if tailscale status >/dev/null 2>&1; then
    add ts-down "$ICON_VPN  Tailscale  $(dim 'on · click to turn off')"
  else
    add ts-up   "$ICON_VPN  Tailscale  $(dim 'off · click to turn on')"
  fi
fi

add settings "$ICON_SETTINGS  Advanced settings…"

# Preselect the active connection's row
selected=0
for i in "${!actions[@]}"; do
  case "${actions[$i]}" in active:*|eth-down) selected=$i; break ;; esac
done

choice=$(printf '%s\n' "${labels[@]}" \
  | rofi_menu -p Network -mesg "$mesg" -format i -selected-row "$selected") || exit 0
[ -z "$choice" ] && exit 0
action=${actions[$choice]}

ask_password() {
  rofi -dmenu -password -p "Password" -theme menu \
    -theme-str 'listview { lines: 0; }' -mesg "$(esc <<<"$1")" </dev/null
}

# run <success message> <failure message> <command...>: notify either way
run() {
  local ok=$1 fail=$2 out
  shift 2
  if out=$("$@" 2>&1); then
    notify "$ok"
  else
    notify -u critical "$fail" "$out"
    return 1
  fi
}

connect_wifi() {
  local security=$1 ssid=$2 pw
  local open=false
  { [ -z "$security" ] || [ "$security" = "--" ]; } && open=true
  notify "Connecting to $ssid…"
  if is_saved "$ssid"; then
    nmcli connection up id "$ssid" >/dev/null 2>&1 && { notify "Connected to $ssid"; return; }
    $open && { notify -u critical "Couldn't connect to $ssid"; return; }
    # Saved password may be stale: ask again and update the profile
    pw=$(ask_password "Couldn't connect to $ssid — re-enter the password") || return 0
    nmcli connection modify id "$ssid" wifi-sec.psk "$pw"
    run "Connected to $ssid" "Couldn't connect to $ssid" nmcli connection up id "$ssid" || true
  elif $open; then
    run "Connected to $ssid" "Couldn't connect to $ssid" nmcli device wifi connect "$ssid" || true
  else
    pw=$(ask_password "$ssid") || return 0
    [ -z "$pw" ] && return 0
    if ! run "Connected to $ssid" "Couldn't connect to $ssid" nmcli device wifi connect "$ssid" password "$pw"; then
      # Don't leave a half-made profile with a wrong password behind
      nmcli connection delete id "$ssid" >/dev/null 2>&1 || true
    fi
  fi
}

case "$action" in
  none) exec "$0" ;;
  eth-up)   run "Ethernet connected" "Ethernet failed" nmcli device connect "$eth_dev" || true ;;
  eth-down) run "Ethernet disconnected" "Couldn't disconnect Ethernet" nmcli device disconnect "$eth_dev" || true ;;
  active:*)
    ssid=${action#active:}
    sub=$(printf '%s\n' "Disconnect" "Forget network" \
      | rofi_menu -p "$(esc <<<"$ssid")" -format i) || exit 0
    case "$sub" in
      0) run "Disconnected from $ssid" "Couldn't disconnect" nmcli device disconnect "$wifi_dev" || true ;;
      1) run "Forgot $ssid" "Couldn't forget $ssid" nmcli connection delete id "$ssid" || true ;;
    esac ;;
  wifi:*)
    rest=${action#wifi:}
    connect_wifi "${rest%%:*}" "${rest#*:}" ;;
  rescan)
    nmcli device wifi rescan >/dev/null 2>&1 || true
    sleep 2
    exec "$0" ;;
  wifi-off) nmcli radio wifi off ;;
  wifi-on)
    nmcli radio wifi on
    sleep 3
    exec "$0" ;;
  ts-up)   run "Tailscale on" "Tailscale failed to start" tailscale up || true; pkill -RTMIN+8 waybar || true ;;
  ts-down) run "Tailscale off" "Tailscale failed to stop" tailscale down || true; pkill -RTMIN+8 waybar || true ;;
  settings) exec nm-connection-editor ;;
esac
