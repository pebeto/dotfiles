#!/bin/bash
# Notification-only handler for kernel/EC-driven hardware keys. The
# kernel performs the state change in parallel; we wait for it to
# settle, then post the resulting state as a notification. Userspace
# actions (volume/mic/layout) are inlined in the sway config; they
# don't notify because the bar already shows them.

ACPI_SETTLE=0.15

notify() {
    # notify <app> <icon> <stack_tag> <body>
    local app=$1 icon=$2 tag=$3 body=$4
    # The stack tag makes a repeat replace the previous notification.
    notify-send -a "$app" -i "$icon" -h "string:x-canonical-private-synchronous:$tag" "$body"
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
