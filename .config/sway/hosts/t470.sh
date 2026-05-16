#!/bin/bash
# T470 barspec: per-core temps, brightness, dual battery (i+e), WiFi SSID
# plus standard audio / layout / time blocks. Sourced by barspec.sh via
# the ~/.config/sway-host.sh symlink, AFTER barspec-lib.sh has set up
# the fifo, click handler, and emitted the i3bar JSON header.

BACKLIGHT=/sys/class/backlight/intel_backlight

SEP_COLOR="#5e5e5e"
COLOR_DIM="#888888"
COLOR_LOW="#ff5555"
# Battery turns red only when one pack is fully depleted (0%) AND the
# other is at or below this threshold — i.e. the system has effectively
# lost one battery and the survivor is also low.
BAT_PARTNER_THRESHOLD=15

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

brightness_pct() {
    [ -r "$BACKLIGHT/brightness" ] || { echo "?"; return; }
    local cur max
    cur=$(< "$BACKLIGHT/brightness")
    max=$(< "$BACKLIGHT/max_brightness")
    echo "$(( cur * 100 / max ))%"
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

SENSORS=""

# Both functions parse the cached output to avoid forking `sensors` twice.
cpu_temps() {
    awk '
        /Core/ {
            gsub("\\+|°C","",$3)
            printf "%sCore %d: %s°C", sep, n, $3
            sep=" ~ "
            n++
        }' <<< "$SENSORS"
}

cpu_max_temp() {
    awk '
        /Core/ { gsub("\\+|°C","",$3); if ($3+0 > m) m=$3+0 }
        END { if (m>0) printf "%.0f", m; else print "?" }' <<< "$SENSORS"
}

while true; do
    SENSORS=$(sensors 2>/dev/null)
    cpu=$(cpu_temps)
    mem=$(memory_pct)
    sys_text="$cpu ~ RAM: ${mem}%"
    sys_color=$(worst_color "$(cpu_max_temp) 70 85" "$mem 80 90")
    bri=$(brightness_pct)
    vol=$(volume_pct)
    bat0=$(battery_segment 0)
    bat1=$(battery_segment 1)
    lay=$(layout_short)
    wifi=$(wifi_label)
    dt=$(date "+%Y-%m-%d %H:%M:%S")

    # Focus mode label — green dot when active, dim "Focus" when off.
    if focus_on; then focus_text="● FOCUS"; focus_color="$COLOR_FOCUS"
    else              focus_text="Focus";   focus_color="$COLOR_DIM"
    fi

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

    {
        printf '['
        printf '%s,%s,'  "$(block focus      "$focus_text"  "$focus_color")" "$(sep)"
        printf '%s,%s,'  "$(block cpu        "$sys_text"    "$sys_color")"   "$(sep)"
        printf '%s,%s,'  "$(block brightness "Brightness: $bri")"            "$(sep)"
        printf '%s,%s,'  "$(block volume     "$vol_text"    "$vol_color")"   "$(sep)"
        if [ -n "$bat_text" ]; then
            printf '%s,%s,'  "$(block battery "$bat_text"   "$bat_color")"   "$(sep)"
        fi
        printf '%s,%s,'  "$(block wifi      "WiFi: $wifi"   "$wifi_color")"  "$(sep)"
        printf '%s,%s,'  "$(block layout    "Layout: $lay")"                 "$(sep)"
        printf '%s'      "$(block time      "$dt")"
        printf '],\n'
    }

    # Sleep up to 1s, but wake immediately when indicators.sh or a key binding writes to the fifo
    read -t 1 -u 3
done
