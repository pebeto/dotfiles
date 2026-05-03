#!/bin/bash
# Hardware-key handler for sway. Volume/mic/layout are driven from
# userspace (amixer, swaymsg) so we do those ourselves and notify on
# the resulting state.

BAR_REFRESH_FIFO="${XDG_RUNTIME_DIR:-/run/user/$(id -u)}/sway-bar-refresh"

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
    up|down|mute) audio_volume "$1" ;;
    mic)          audio_mic ;;
    layout)       layout_switch ;;
    *)            exit 1 ;;
esac

bar_refresh
