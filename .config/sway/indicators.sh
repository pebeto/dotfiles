#!/bin/bash
# Notification-only handler for kernel/EC-driven hardware keys. The
# kernel performs the state change in parallel; we wait briefly for
# it to settle, then dunstify the resulting state and nudge the bar
# to refresh. Userspace actions (volume/mic/layout) are inlined in
# the sway config — they don't notify because the bar already shows
# them.

BAR_REFRESH_FIFO="${XDG_RUNTIME_DIR:-/run/user/$(id -u)}/sway-bar-refresh"
ACPI_SETTLE=0.15

notify() {
    # notify <app> <icon> <stack_tag> <body>
    local app=$1 icon=$2 tag=$3 body=$4
    dunstify -a "$app" -i "$icon" -h "string:x-dunst-stack-tag:$tag" "$body"
}

bar_refresh() {
    [ -p "$BAR_REFRESH_FIFO" ] && echo > "$BAR_REFRESH_FIFO" 2>/dev/null
}

radio_state() {
    # radio_state <wifi|bluetooth> -> "On" | "Off"
    local soft
    soft=$(rfkill list "$1" -o SOFT -n 2>/dev/null | head -1)
    [ "$soft" = "blocked" ] && echo "Off" || echo "On"
}

acpi_radio() {
    # acpi_radio <wifi|bluetooth>
    sleep "$ACPI_SETTLE"
    local kind=$1 state
    state=$(radio_state "$1")
    case "$kind" in
        wifi)
            notify "WiFi" "network-wireless" "wifi" "WiFi: $state"
            ;;
        bluetooth)
            local icon=bluetooth-active
            [ "$state" = "Off" ] && icon=bluetooth-disabled
            notify "Bluetooth" "$icon" "bluetooth" "Bluetooth: $state"
            ;;
    esac
}

fnlock_state() {
    # ThinkPad FnLock state: 1 = locked (F-keys primary), 0 = unlocked.
    local v
    v=$(cat /sys/class/leds/tpacpi::fnlock/brightness 2>/dev/null)
    case "$v" in
        1) echo "On" ;;
        0) echo "Off" ;;
        *) echo "?" ;;
    esac
}

acpi_fnlock() {
    sleep "$ACPI_SETTLE"
    local state
    state=$(fnlock_state)
    notify "FnLock" "input-keyboard" "fnlock" "FnLock: $state"
}

case "$1" in
    wifi|bluetooth) acpi_radio "$1" ;;
    fnlock)         acpi_fnlock ;;
    *)              exit 1 ;;
esac

bar_refresh
