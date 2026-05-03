#!/bin/bash
# i3bar JSON status command for swaybar.
#
# Emits a header + an infinite array of status arrays. Each refresh tick
# corresponds to one status array containing one block per metric.
# click_events:true lets swaybar deliver click events on stdin; we read
# them in a background process and dispatch (currently: click volume to
# toggle mute).

BAR_REFRESH_FIFO="${XDG_RUNTIME_DIR:-/run/user/$(id -u)}/sway-bar-refresh"

[ -p "$BAR_REFRESH_FIFO" ] || mkfifo "$BAR_REFRESH_FIFO"
exec 3<>"$BAR_REFRESH_FIFO"

volume_pct()    { amixer get Master 2>/dev/null | grep -m1 -oE '[0-9]+%'; }
volume_muted()  { amixer get Master 2>/dev/null | grep -q '\[off\]'; }

layout_short() {
    local idx
    idx=$(swaymsg -t get_inputs 2>/dev/null \
          | grep -m1 "xkb_active_layout_index" | grep -oE '[0-9]+')
    case "$idx" in
        0) echo "us" ;;
        1) echo "latam" ;;
        *) echo "?" ;;
    esac
}

cpu_temp() {
    sensors 2>/dev/null | awk '/CPU Package:/ {gsub("\\+|°C","",$3); print $3; exit}'
}

gpu_temp() {
    nvidia-smi --query-gpu=temperature.gpu --format=csv,noheader,nounits 2>/dev/null
}

json_escape() {
    local s=$1
    s=${s//\\/\\\\}
    s=${s//\"/\\\"}
    printf '%s' "$s"
}

block() {
    # block <name> <full_text> [color]
    # Each block opts out of the default vertical separator/padding so the
    # explicit sep() block below provides consistent spacing.
    local name=$1 text=$2 color=${3:-}
    if [ -n "$color" ]; then
        printf '{"name":"%s","full_text":"%s","color":"%s","separator":false,"separator_block_width":0}' \
            "$name" "$(json_escape "$text")" "$color"
    else
        printf '{"name":"%s","full_text":"%s","separator":false,"separator_block_width":0}' \
            "$name" "$(json_escape "$text")"
    fi
}

SEP_COLOR="#5e5e5e"
sep() {
    printf '{"name":"sep","full_text":" │ ","color":"%s","separator":false,"separator_block_width":0}' \
        "$SEP_COLOR"
}

toggle_cal_popup() {
    local pidfile="${XDG_RUNTIME_DIR:-/run/user/$(id -u)}/cal-popup.pid"
    if [ -f "$pidfile" ] && kill -0 "$(cat "$pidfile")" 2>/dev/null; then
        kill "$(cat "$pidfile")" 2>/dev/null
        rm -f "$pidfile"
    else
        # Enable xterm mouse tracking after `cal` so clicks inside foot send an
        # escape sequence to stdin; `read -n1` then consumes the first byte
        # (any click or keypress) and exits, which closes the foot window.
        foot --app-id=cal-popup \
             -- bash -c 'cal; printf "\033[?1000h"; read -rsn1; printf "\033[?1000l"' \
             >/dev/null 2>&1 &
        echo $! > "$pidfile"
    fi
}

dispatch_click() {
    case "$1" in
        *'"name": "volume"'*|*'"name":"volume"'*) amixer set Master toggle > /dev/null ;;
        *'"name": "time"'*|*'"name":"time"'*)     toggle_cal_popup ;;
        *'"name": "layout"'*|*'"name":"layout"'*) swaymsg input type:keyboard xkb_switch_layout next > /dev/null ;;
        *) return ;;
    esac
    echo > "$BAR_REFRESH_FIFO" 2>/dev/null
}

handle_clicks() {
    while IFS= read -r line; do
        dispatch_click "$line"
    done
}

# In non-interactive shells, bash redirects bg jobs' stdin to /dev/null
# by default, which would silently swallow swaybar's click events. Save
# the original stdin to fd 4 and route the handler's stdin from there.
exec 4<&0
handle_clicks <&4 &
trap "kill $! 2>/dev/null" EXIT

COLOR_DIM="#888888"

printf '{"version":1,"click_events":true}\n[\n'

while true; do
    cpu=$(cpu_temp)
    gpu=$(gpu_temp)
    vol=$(volume_pct)
    lay=$(layout_short)
    dt=$(date "+%Y-%m-%d %H:%M:%S")

    temp_text="CPU: ${cpu:-?}°C ~ GPU: ${gpu:-?}°C"

    # Volume label — dim gray when muted
    vol_color=""
    if volume_muted; then
        vol_text="Volume: Muted"
        vol_color="$COLOR_DIM"
    else
        vol_text="Volume: ${vol:-?}"
    fi

    {
        printf '['
        printf '%s,%s,'  "$(block temp   "$temp_text")"             "$(sep)"
        printf '%s,%s,'  "$(block volume "$vol_text" "$vol_color")" "$(sep)"
        printf '%s,%s,'  "$(block layout "Layout: $lay")"           "$(sep)"
        printf '%s'      "$(block time   "$dt")"
        printf '],\n'
    }

    # Sleep up to 1s, but wake immediately when a key binding writes to the fifo
    read -t 1 -u 3
done
