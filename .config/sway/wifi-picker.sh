#!/bin/bash
# Fuzzel-based WiFi picker for iwd-based systems. Lists nearby networks via
# iwctl, prompts via fuzzel --dmenu, and connects — asking for a passphrase
# via fuzzel --password only when the network isn't already known to iwd.
#
# Invoked from barspec-lib.sh when the user clicks the "wifi" bar block.

set -u

notify() {
    command -v notify-send >/dev/null 2>&1 && notify-send -a "WiFi" "WiFi" "$1"
}

if ! command -v iwctl >/dev/null 2>&1; then
    notify "iwctl is not installed"
    exit 1
fi

iface=$(iw dev 2>/dev/null | awk '$1=="Interface"{print $2; exit}')
[ -z "$iface" ] && { notify "No wireless interface found"; exit 1; }

# Strip ANSI escape sequences from iwctl's pretty-printed output.
strip_ansi() { sed -E 's/\x1b\[[0-9;]*[mKHGJ]//g'; }

iwctl station "$iface" scan >/dev/null 2>&1 || true
sleep 1

# Find a security keyword in each line. SSID is everything before it, signal
# everything after. Handles SSIDs with spaces because we don't field-split.
choices=$(iwctl station "$iface" get-networks 2>/dev/null | strip_ansi |
          awk '{
              if (match($0, /[[:space:]](psk|open|8021x|wep)([[:space:]]|$)/, m)) {
                  ssid = substr($0, 1, RSTART - 1)
                  sub(/^[[:space:]]*>?[[:space:]]*/, "", ssid)
                  sub(/[[:space:]]+$/, "", ssid)
                  sec = m[1]
                  signal_pos = RSTART + RLENGTH
                  signal = substr($0, signal_pos)
                  gsub(/^[[:space:]]+|[[:space:]]+$/, "", signal)
                  if (ssid != "" && ssid != "Network name")
                      printf "%-32s  %-6s  %s\n", ssid, sec, signal
              }
          }' | awk '!seen[$0]++')

[ -z "$choices" ] && { notify "No networks visible"; exit 0; }

selected=$(echo "$choices" | fuzzel --dmenu --prompt='WiFi  ')
[ -z "$selected" ] && exit 0

# First column is the SSID; strip the padding spaces.
ssid="${selected%%  *}"
ssid="${ssid%"${ssid##*[![:space:]]}"}"

# Try without a passphrase first. iwctl uses the stored credential for
# known networks; for unknown ones it would prompt on a tty, but we deny
# stdin so it fails quickly and we fall through to the password prompt.
if iwctl station "$iface" connect "$ssid" </dev/null >/dev/null 2>&1; then
    notify "Connected to $ssid"
    exit 0
fi

pw=$(fuzzel --dmenu --password --prompt="$ssid password  " </dev/null) || exit 0
[ -z "$pw" ] && exit 0

if iwctl --passphrase "$pw" station "$iface" connect "$ssid" </dev/null >/dev/null 2>&1; then
    notify "Connected to $ssid"
else
    notify "Failed to connect to $ssid"
fi
