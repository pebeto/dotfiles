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

# Color the temp block on the hottest of CPU/GPU.
hottest_color() {
    local hottest=0 v
    for v in "$@"; do
        [ -z "$v" ] || [ "$v" = "?" ] && continue
        v=${v%.*}
        [ "$v" -gt "$hottest" ] 2>/dev/null && hottest=$v
    done
    threshold_color "$hottest" 70 85
}

while true; do
    SENSORS=$(sensors 2>/dev/null)
    cpu=$(cpu_temp)
    gpu=$(gpu_temp)
    mem=$(memory_pct)
    vol=$(volume_pct)
    lay=$(layout_short)
    dt=$(date "+%Y-%m-%d %H:%M:%S")

    temp_text="CPU: ${cpu:-?}°C ~ GPU: ${gpu:-?}°C"
    temp_color=$(hottest_color "$cpu" "$gpu")

    mem_text="Mem: ${mem}%"
    mem_color=$(threshold_color "$mem" 80 90)

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
        printf '%s,%s,'  "$(block temp   "$temp_text" "$temp_color")" "$(sep)"
        printf '%s,%s,'  "$(block memory "$mem_text"  "$mem_color")"  "$(sep)"
        printf '%s,%s,'  "$(block volume "$vol_text"  "$vol_color")"  "$(sep)"
        printf '%s,%s,'  "$(block layout "Layout: $lay")"             "$(sep)"
        printf '%s'      "$(block time   "$dt")"
        printf '],\n'
    }

    # Sleep up to 1s, but wake immediately when a key binding writes to the fifo
    read -t 1 -u 3
done
