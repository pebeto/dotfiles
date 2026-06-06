#!/bin/bash
# Fuzzel-based Bluetooth device picker, mirroring wifi-picker.sh. Starts the
# bluetooth daemon if needed, powers the controller on, scans for nearby
# devices, lists paired and visible ones, and toggles the connection on the
# chosen device (pair+trust+connect when new, disconnect when already on).
#
# Bound to $mod+F10 on the T470.
#
# Every bluetoothctl call goes through `timeout`: with bluetoothd stopped,
# bluetoothctl blocks rather than failing, which would hang the picker.

set -u

notify() {
    command -v notify-send >/dev/null 2>&1 && notify-send -a "Bluetooth" "Bluetooth" "$1"
}

# All bluetoothctl access goes through here so a stuck daemon can't hang us.
bt() { timeout 6 bluetoothctl "$@"; }

command -v bluetoothctl >/dev/null 2>&1 || { notify "bluetoothctl is not installed"; exit 1; }

# The picker needs bluetoothd. If it's stopped, try to start it (this needs a
# polkit agent and fails fast without one). Re-check before giving up.
if ! systemctl is-active --quiet bluetooth; then
    timeout 10 systemctl start bluetooth >/dev/null 2>&1 || true
    if ! systemctl is-active --quiet bluetooth; then
        notify "Bluetooth service is not running (start it: systemctl start bluetooth)"
        exit 1
    fi
fi

# The tpacpi adapter de-registers from the system while rfkill soft-blocks
# it: no hci device, no bluez controller. Unblock it, then wait for bluez to
# register the controller.
rfkill unblock bluetooth 2>/dev/null || true
for _ in $(seq 1 12); do
    [ -n "$(bt list 2>/dev/null)" ] && break
    sleep 0.5
done
[ -n "$(bt list 2>/dev/null)" ] || { notify "No Bluetooth controller found"; exit 1; }

bt power on >/dev/null 2>&1

# Scan so unpaired devices show up.
bt --timeout 4 scan on >/dev/null 2>&1 || true

# Connected / paired MAC sets, so we can mark connected devices and always
# keep paired ones. Both `devices <filter>` forms are best-effort (older
# bluez lacks them).
connected=$(bt devices Connected 2>/dev/null | awk '{print $2}')
paired=$(bt devices Paired 2>/dev/null | awk '{print $2}')
in_set() { printf '%s\n' "$1" | grep -qx "$2"; }

# Build the menu from friendly names only; no MAC is shown. An associative
# array keyed by the displayed label holds the MAC for recovery after the
# pick. bluetoothctl reports the dash-form MAC as the "name" for devices that
# advertise none, which are nearby BLE noise, so skip those unless paired.
# Process substitution (not a pipe) keeps the array in the parent shell.
declare -A MAC_OF
menu=""
while read -r _ mac name; do
    [ -z "$mac" ] && continue
    if [ "$name" = "${mac//:/-}" ]; then
        in_set "$paired" "$mac" || continue   # unnamed and not ours -> hide
        name="Unknown device"
    fi
    in_set "$connected" "$mac" && dot="●" || dot="○"
    label="$dot $name"
    MAC_OF["$label"]="$mac"
    menu+="$label"$'\n'
done < <(bt devices 2>/dev/null)

[ -z "$menu" ] && { notify "No named or paired devices found"; exit 0; }

selected=$(printf '%s' "$menu" | fuzzel --dmenu --prompt='Bluetooth  ')
[ -z "$selected" ] && exit 0

mac="${MAC_OF[$selected]}"
[ -z "$mac" ] && exit 0
name="${selected#* }"                          # strip the leading status dot
is_connected() { in_set "$connected" "$1"; }

if is_connected "$mac"; then
    if bt disconnect "$mac" >/dev/null 2>&1; then
        notify "Disconnected $name"
    else
        notify "Failed to disconnect $name"
    fi
else
    # pair + trust are harmless no-ops if the device is already known.
    bt pair "$mac"  >/dev/null 2>&1 || true
    bt trust "$mac" >/dev/null 2>&1 || true
    if bt connect "$mac" >/dev/null 2>&1; then
        notify "Connected $name"
    else
        notify "Failed to connect $name"
    fi
fi
