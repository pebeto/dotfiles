#!/bin/bash
# Workstation barspec: CPU package temp + NVIDIA GPU temp + standard
# audio / layout / time blocks. Sourced by ~/.config/sway/barspec.sh
# via the ~/.config/sway-host.sh symlink, AFTER barspec-lib.sh has set
# up the fifo, click handler, and emitted the i3bar JSON header.

SEP_COLOR="#b7b19c"
COLOR_DIM="#b7b19c"

SENSORS=""

# Both metrics parse the cached sensors output to avoid forking `sensors`
# twice per tick.
cpu_temp() { awk '/CPU Package:/ {gsub("\\+|°C","",$3); print $3; exit}' <<< "$SENSORS"; }
gpu_temp() { nvidia-smi --query-gpu=temperature.gpu --format=csv,noheader,nounits 2>/dev/null; }

# Hottest of multiple temperature values (strips decimals; ignores ? / empty).
hottest_temp() {
    local hottest=0 v
    for v in "$@"; do
        [ -z "$v" ] || [ "$v" = "?" ] && continue
        v=${v%.*}
        [ "$v" -gt "$hottest" ] 2>/dev/null && hottest=$v
    done
    printf '%s' "$hottest"
}

while true; do
    SENSORS=$(sensors 2>/dev/null)
    cpu=$(cpu_temp)
    gpu=$(gpu_temp)
    mem=$(memory_pct)
    vol=$(volume_pct)
    lay=$(layout_short)
    dt=$(date "+%Y-%m-%d %H:%M:%S")

    sys_text="CPU: ${cpu:-?}°C ~ GPU: ${gpu:-?}°C ~ RAM: ${mem}%"
    sys_color=$(worst_color "$(hottest_temp "$cpu" "$gpu") 70 85" "$mem 80 90")

    # Focus mode label — green dot when active, dim "Focus" when off.
    if focus_on; then focus_text="● FOCUS"; focus_color="$COLOR_FOCUS"
    else              focus_text="Focus";   focus_color="$COLOR_DIM"
    fi

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
        printf '%s,%s,'  "$(block focus  "$focus_text" "$focus_color")" "$(sep)"
        printf '%s,%s,'  "$(block temp   "$sys_text"   "$sys_color")"   "$(sep)"
        printf '%s,%s,'  "$(block volume "$vol_text"   "$vol_color")"   "$(sep)"
        printf '%s,%s,'  "$(block layout "Layout: $lay")"               "$(sep)"
        printf '%s'      "$(block time   "$dt")"
        printf '],\n'
    }

    # Sleep up to 1s, but wake immediately when a key binding writes to the fifo
    read -t 1 -u 3
done
