#!/bin/bash
# Shared swaybar helpers. Sourced by per-host barspec.sh scripts; on source
# this sets up the click-handler background job, opens the refresh fifo on
# fd 3, and prints the i3bar JSON header. Hosts then loop and print status
# arrays using the helpers below.
#
# Hosts can override SEP_COLOR / COLOR_DIM before sourcing.

BAR_REFRESH_FIFO="${XDG_RUNTIME_DIR:-/run/user/$(id -u)}/sway-bar-refresh"
[ -p "$BAR_REFRESH_FIFO" ] || mkfifo "$BAR_REFRESH_FIFO"
exec 3<>"$BAR_REFRESH_FIFO"

SEP_COLOR="${SEP_COLOR:-#b7b19c}"
COLOR_DIM="${COLOR_DIM:-#b7b19c}"
COLOR_WARN="${COLOR_WARN:-#ffaa00}"
COLOR_LOW="${COLOR_LOW:-#ff5555}"
COLOR_FOCUS="${COLOR_FOCUS:-#88cc88}"

FOCUS_STATE_FILE="${XDG_RUNTIME_DIR:-/run/user/$(id -u)}/focus-mode.state"

# focus_on returns 0 if focus mode is active.
focus_on() { [ -f "$FOCUS_STATE_FILE" ]; }

threshold_color() {
    # threshold_color <value> <warn> <crit> -> emits COLOR_WARN or COLOR_LOW
    # for values at/above each threshold, nothing otherwise. Accepts plain
    # numbers as well as "85%", "63.5", "63.5°C".
    local v=$1 warn=$2 crit=$3
    [ -z "$v" ] || [ "$v" = "?" ] && return 0
    v=${v%\%}; v=${v%°*}; v=${v%.*}
    [ -z "$v" ] && return 0
    if [ "$v" -ge "$crit" ] 2>/dev/null; then
        printf '%s' "$COLOR_LOW"
    elif [ "$v" -ge "$warn" ] 2>/dev/null; then
        printf '%s' "$COLOR_WARN"
    fi
}

worst_color() {
    # worst_color "<value> <warn> <crit>" ["<value> <warn> <crit>" ...]
    # Returns COLOR_LOW if any spec hits crit, else COLOR_WARN if any hits
    # warn, else nothing. Lets one combined block reflect the worst metric.
    local worst=0 spec v warn crit c
    for spec in "$@"; do
        read -r v warn crit <<< "$spec"
        c=$(threshold_color "$v" "$warn" "$crit")
        if [ "$c" = "$COLOR_LOW" ] && [ "$worst" -lt 2 ]; then
            worst=2
        elif [ "$c" = "$COLOR_WARN" ] && [ "$worst" -lt 1 ]; then
            worst=1
        fi
    done
    case "$worst" in
        2) printf '%s' "$COLOR_LOW" ;;
        1) printf '%s' "$COLOR_WARN" ;;
    esac
}

memory_pct() {
    awk '/^MemTotal:/{t=$2} /^MemAvailable:/{a=$2} END{ if(t>0) printf "%d", (t-a)*100/t; else print "?" }' /proc/meminfo
}

volume_pct()   { amixer get Master 2>/dev/null | grep -m1 -oE '[0-9]+%'; }
volume_muted() { amixer get Master 2>/dev/null | grep -q '\[off\]'; }

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

toggle_btop_popup() {
    local pidfile="${XDG_RUNTIME_DIR:-/run/user/$(id -u)}/btop-popup.pid"
    if [ -f "$pidfile" ] && kill -0 "$(cat "$pidfile")" 2>/dev/null; then
        kill "$(cat "$pidfile")" 2>/dev/null
        rm -f "$pidfile"
    else
        # btop is interactive; user closes with 'q' inside the window or by
        # clicking the bar block again (toggle path above).
        foot --app-id=btop-popup -- btop >/dev/null 2>&1 &
        echo $! > "$pidfile"
    fi
}

dispatch_click() {
    local line=$1 btn=1
    # i3bar buttons: 1=left, 2=middle, 3=right, 4=scroll-up, 5=scroll-down
    [[ "$line" =~ \"button\"[[:space:]]*:[[:space:]]*([0-9]+) ]] && btn=${BASH_REMATCH[1]}

    case "$line" in
        *'"name": "volume"'*|*'"name":"volume"'*)
            case "$btn" in
                4) amixer set Master 5%+    > /dev/null ;;
                5) amixer set Master 5%-    > /dev/null ;;
                *) amixer set Master toggle > /dev/null ;;
            esac ;;
        *'"name": "brightness"'*|*'"name":"brightness"'*)
            case "$btn" in
                4) brightnessctl set 5%+ > /dev/null 2>&1 ;;
                5) brightnessctl set 5%- > /dev/null 2>&1 ;;
            esac ;;
        *'"name": "wifi"'*|*'"name":"wifi"'*)     ~/.config/sway/wifi-picker.sh >/dev/null 2>&1 & ;;
        *'"name": "focus"'*|*'"name":"focus"'*)   ~/.config/sway/focus-toggle.sh ;;
        *'"name": "time"'*|*'"name":"time"'*)     toggle_cal_popup ;;
        *'"name": "temp"'*|*'"name":"temp"'*)     toggle_btop_popup ;;
        *'"name": "cpu"'*|*'"name":"cpu"'*)       toggle_btop_popup ;;
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

printf '{"version":1,"click_events":true}\n[\n'
