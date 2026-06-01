#!/usr/bin/env bash
# Render Wi-Fi or Ethernet status for polybar.
# Default: just the icon. Click toggles a state file that also shows the name.
#
# Usage:  network.sh wlan        # render wifi
#         network.sh eth         # render ethernet
#         network.sh wlan toggle # flip expanded/collapsed
#         network.sh eth  toggle

type="$1"
action="$2"

state_dir="${XDG_RUNTIME_DIR:-/tmp}"
state_file="$state_dir/polybar-network-$type"

if [[ "$action" == "toggle" ]]; then
    if [[ -f "$state_file" ]]; then
        rm -f "$state_file"
    else
        touch "$state_file"
    fi
    exit 0
fi

icon_color="#458588"
text_color="#FFFFFF"

case "$type" in
    wlan)
        iface=$(iw dev 2>/dev/null | awk '$1=="Interface"{print $2; exit}')
        [[ -z "$iface" ]] && exit 0
        # Must be UP to be considered connected.
        ip -o link show "$iface" up >/dev/null 2>&1 || exit 0
        essid=$(iwgetid -r "$iface" 2>/dev/null)
        [[ -z "$essid" ]] && exit 0
        icon="󰤨"
        label="$essid"
        ;;
    eth)
        iface=$(ip -o link show up 2>/dev/null \
            | awk -F': ' '$2 !~ /^(lo|wl|docker|veth|br-|tun|tap|tailscale|virbr)/ {print $2; exit}')
        [[ -z "$iface" ]] && exit 0
        ip -o -4 addr show "$iface" 2>/dev/null | grep -q . || exit 0
        icon=""
        label="$iface"
        ;;
    *)
        exit 1
        ;;
esac

if [[ -f "$state_file" ]]; then
    printf '%%{F%s}%s%%{F-} %%{F%s}%s%%{F-}\n' "$icon_color" "$icon" "$text_color" "$label"
else
    printf '%%{F%s}%s%%{F-}\n' "$icon_color" "$icon"
fi
