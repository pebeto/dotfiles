#!/bin/bash
# i3bar JSON status command for swaybar.
#
# Emits a header + an infinite array of status arrays. Each refresh tick
# corresponds to one status array containing one block per metric.
# click_events:true lets swaybar deliver click events on stdin; we read
# them in a background process and dispatch (currently: click volume to
# toggle mute).

BACKLIGHT=/sys/class/backlight/intel_backlight
BAR_REFRESH_FIFO="${XDG_RUNTIME_DIR:-/run/user/$(id -u)}/sway-bar-refresh"

[ -p "$BAR_REFRESH_FIFO" ] || mkfifo "$BAR_REFRESH_FIFO"
exec 3<>"$BAR_REFRESH_FIFO"

read_sysfs() { [ -r "$1" ] && cat "$1"; }

battery_capacity() { read_sysfs "/sys/class/power_supply/BAT$1/capacity"; }
battery_status()   { read_sysfs "/sys/class/power_supply/BAT$1/status"; }

battery_segment() {
    # battery_segment <n> -> "+85%", "-30%", "" (if missing)
    local n=$1 cap status marker
    cap=$(battery_capacity "$n")
    [ -z "$cap" ] && return
    status=$(battery_status "$n")
    case "$status" in
        Charging)    marker="+" ;;
        Discharging) marker="-" ;;
        *)           marker=""  ;;
    esac
    printf '%s%s%%' "$marker" "$cap"
}

volume_pct()    { amixer get Master 2>/dev/null | grep -m1 -oE '[0-9]+%'; }
volume_muted()  { amixer get Master 2>/dev/null | grep -q '\[off\]'; }

brightness_pct() {
    [ -r "$BACKLIGHT/brightness" ] || { echo "?"; return; }
    local cur max
    cur=$(< "$BACKLIGHT/brightness")
    max=$(< "$BACKLIGHT/max_brightness")
    echo "$(( cur * 100 / max ))%"
}

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

radio_state() {
    # radio_state <wifi|bluetooth> -> "On" | "Off" | "?"
    local soft
    soft=$(rfkill list "$1" -o SOFT -n 2>/dev/null | head -1)
    case "$soft" in
        unblocked) echo "On" ;;
        blocked)   echo "Off" ;;
        *)         echo "?" ;;
    esac
}

wifi_label() {
    # When the radio is up, prefer the connected SSID over "On". Falls
    # back to the radio_state value (Off / ? / On) when not associated.
    local state ssid iface line
    state=$(radio_state wifi)
    [ "$state" != "On" ] && { echo "$state"; return; }
    iface=$(iw dev 2>/dev/null | awk '$1=="Interface"{print $2; exit}')
    [ -z "$iface" ] && { echo "On"; return; }
    line=$(iw dev "$iface" link 2>/dev/null | grep -m1 $'^\tSSID:')
    ssid=${line#*SSID: }
    [ -n "$ssid" ] && echo "$ssid" || echo "On"
}

cpu_temps() {
    sensors 2>/dev/null | awk '
        /Core/ {
            gsub("\\+|°C","",$3)
            printf "%sCore %d: %s°C", sep, n, $3
            sep=" ~ "
            n++
        }'
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
COLOR_LOW="#ff5555"
# Battery turns red only when one pack is fully depleted (0%) AND the
# other is at or below this threshold — i.e. the system has effectively
# lost one battery and the survivor is also low.
BAT_PARTNER_THRESHOLD=15

printf '{"version":1,"click_events":true}\n[\n'

while true; do
    cpu=$(cpu_temps)
    bri=$(brightness_pct)
    vol=$(volume_pct)
    bat0=$(battery_segment 0)
    bat1=$(battery_segment 1)
    lay=$(layout_short)
    wifi=$(wifi_label)
    bt=$(radio_state bluetooth)
    dt=$(date "+%Y-%m-%d %H:%M:%S")

    # Volume label — dim gray when muted, like off-state radios
    vol_color=""
    if volume_muted; then
        vol_text="Volume: Muted"
        vol_color="$COLOR_DIM"
    else
        vol_text="Volume: ${vol:-?}"
    fi

    # Battery label, plus low-battery color if any pack is below threshold
    bat_text=""
    [ -n "$bat0" ] && bat_text="iBAT: $bat0"
    if [ -n "$bat1" ]; then
        [ -n "$bat_text" ] && bat_text+=" ~ "
        bat_text+="eBAT: $bat1"
    fi
    bat_color=""
    if [ -n "$bat0" ] && [ -n "$bat1" ]; then
        n0=${bat0#[+-]}; n0=${n0%\%}
        n1=${bat1#[+-]}; n1=${n1%\%}
        if { [ "$n0" -eq 0 ] && [ "$n1" -le "$BAT_PARTNER_THRESHOLD" ]; } || \
           { [ "$n1" -eq 0 ] && [ "$n0" -le "$BAT_PARTNER_THRESHOLD" ]; } 2>/dev/null; then
            bat_color="$COLOR_LOW"
        fi
    fi

    wifi_color=""; [ "$wifi" = "Off" ] && wifi_color="$COLOR_DIM"
    bt_color="";   [ "$bt" = "Off" ]   && bt_color="$COLOR_DIM"

    {
        printf '['
        printf '%s,%s,'  "$(block cpu        "$cpu")"                      "$(sep)"
        printf '%s,%s,'  "$(block brightness "Brightness: $bri")"          "$(sep)"
        printf '%s,%s,'  "$(block volume     "$vol_text" "$vol_color")"    "$(sep)"
        if [ -n "$bat_text" ]; then
            printf '%s,%s,'  "$(block battery "$bat_text" "$bat_color")"   "$(sep)"
        fi
        printf '%s,%s,'  "$(block wifi      "WiFi: $wifi"  "$wifi_color")" "$(sep)"
        printf '%s,%s,'  "$(block bluetooth "BT: $bt"      "$bt_color")"   "$(sep)"
        printf '%s,%s,'  "$(block layout    "Layout: $lay")"               "$(sep)"
        printf '%s'      "$(block time      "$dt")"
        printf '],\n'
    }

    # Sleep up to 1s, but wake immediately when indicators.sh or a key binding writes to the fifo
    read -t 1 -u 3
done
