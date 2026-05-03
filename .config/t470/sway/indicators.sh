#!/bin/bash
# Hardware-key handler for sway. For ACPI-driven keys (brightness, wifi,
# bluetooth) we don't perform the change ourselves — the kernel ACPI
# handler does that in parallel. We just wait briefly for it to settle
# and then notify with the resulting state. Volume/mic/layout are driven
# from userspace (amixer, swaymsg) so we do those ourselves.

BACKLIGHT=/sys/class/backlight/intel_backlight
BAR_REFRESH_FIFO="${XDG_RUNTIME_DIR:-/run/user/$(id -u)}/sway-bar-refresh"
ACPI_SETTLE=0.15

notify() {
    # notify <app> <icon> <stack_tag> <body> [int_value]
    local app=$1 icon=$2 tag=$3 body=$4 value=${5:-}
    if [ -n "$value" ]; then
        dunstify -a "$app" -i "$icon" -h "string:x-dunst-stack-tag:$tag" -h "int:value:$value" "$body"
    else
        dunstify -a "$app" -i "$icon" -h "string:x-dunst-stack-tag:$tag" "$body"
    fi
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

acpi_brightness() {
    sleep "$ACPI_SETTLE"
    local cur max bright
    cur=$(< "$BACKLIGHT/brightness")
    max=$(< "$BACKLIGHT/max_brightness")
    bright=$(( cur * 100 / max ))
    notify "Brightness" "display-brightness" "bright" "Brightness: ${bright}%" "$bright"
}

acpi_radio() {
    # acpi_radio <wifi|bluetooth>
    sleep "$ACPI_SETTLE"
    local kind=$1 state=$(radio_state "$1")
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

audio_volume() {
    # audio_volume <up|down|mute>
    case "$1" in
        up)   amixer set Master 5%+    > /dev/null ;;
        down) amixer set Master 5%-    > /dev/null ;;
        mute) amixer set Master toggle > /dev/null ;;
    esac
    if amixer get Master 2>/dev/null | grep -q '\[off\]'; then
        notify "Volume" "audio-volume-muted" "volume" "Muted"
    else
        local vol
        vol=$(amixer get Master 2>/dev/null | grep -m1 -oE '[0-9]+%')
        vol=${vol%\%}
        notify "Volume" "audio-volume-high" "volume" "Volume: ${vol}%" "$vol"
    fi
}

audio_mic() {
    amixer set Capture toggle > /dev/null
    if amixer get Capture 2>/dev/null | grep -q '\[off\]'; then
        notify "Microphone" "microphone-sensitivity-muted" "mic" "Microphone Muted"
    else
        notify "Microphone" "microphone-sensitivity-high" "mic" "Microphone On"
    fi
}

layout_switch() {
    swaymsg input type:keyboard xkb_switch_layout next > /dev/null
    sleep 0.05
    local name
    name=$(swaymsg -t get_inputs 2>/dev/null | grep -m1 "xkb_active_layout_name" | cut -d '"' -f4)
    notify "Keyboard" "input-keyboard" "layout" "Layout: $name"
}

case "$1" in
    up|down|mute)        audio_volume "$1" ;;
    mic)                 audio_mic ;;
    brightup|brightdown) acpi_brightness ;;
    wifi|bluetooth)      acpi_radio "$1" ;;
    layout)              layout_switch ;;
    *)                   exit 1 ;;
esac

bar_refresh
