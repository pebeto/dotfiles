#!/bin/bash
# macOS-Notification-Center-style popup for the swaybar clock. Toggled by clicking
# the time block: `toggle_cal_popup` in barspec-lib.sh runs this inside a foot window
# (app_id=cal-popup, sized by the for_window rule in sway/config). It prints styled
# text to stdout; the popup wrapper owns the window and click-to-close.
#
# Sections:
#   - this month's calendar (cal highlights today when writing to a tty)
#   - the current default audio output (labels mirror ~/.local/bin/audio-toggle)
#   - the last 10 dunst notifications (dunstctl history)

B=$'\e[1m'; D=$'\e[2m'; R=$'\e[0m'; y=$'\e[33m'; c=$'\e[36m'; g=$'\e[32m'
WIDTH=48
LINE='────────────────────────────────────────────────────────'

hr()   { printf '%s%.*s%s\n' "$D" "$WIDTH" "$LINE" "$R"; }
clip() { local max=$1 s=$2; (( ${#s} > max )) && s="${s:0:max-1}…"; printf '%s' "$s"; }

# --- date + calendar --------------------------------------------------------
printf '%s%s%s\n\n' "$B" "$(date '+%A, %-d %B %Y')" "$R"
cal

# --- today's agenda (moved off the bar; fed by the agenda-refresh timer cache) ---
echo; hr
printf '%sAgenda%s\n' "$y" "$R"
AGENDA_NO_HEADER=1 ~/.config/sway/agenda.sh pretty

# --- current audio output ---------------------------------------------------
echo; hr
HEADSET="alsa_output.usb-Logitech_PRO_X_Wireless_Gaming_Headset-00.analog-stereo"
HDMI="alsa_output.pci-0000_01_00.1.hdmi-stereo"
sink=$(pactl get-default-sink 2>/dev/null)
case "$sink" in
    "$HEADSET") label="PRO X headset" ;;
    "$HDMI")    label="Samsung screen (HDMI)" ;;
    "")         label="(no sink)" ;;
    *)          label=$(pactl list sinks 2>/dev/null | awk -v s="$sink" \
                    '/^\tName:/{n=($2==s)} n&&/^\tDescription:/{sub(/^\tDescription: /,"");print;exit}')
                label=${label:-$sink} ;;
esac
printf '%s Sound%s  %s%s%s\n' "$c" "$R" "$B" "$label" "$R"

# Syncthing heartbeat via its REST API (key from config.xml). Overall completion:
# "up to date" at 100%, otherwise the percentage still to pull. Localhost + 1s
# timeout so a stopped daemon just shows "(offline)" without stalling the popup.
st_cfg=$(find ~/.local/state/syncthing ~/.config/syncthing -name config.xml 2>/dev/null | head -1)
st_key=$(grep -oPm1 '(?<=<apikey>)[^<]+' "$st_cfg" 2>/dev/null)
st_pct=""
[ -n "$st_key" ] && st_pct=$(curl -s --max-time 1 -H "X-API-Key: $st_key" \
    http://127.0.0.1:8384/rest/db/completion 2>/dev/null | jq -r '.completion // empty' 2>/dev/null)
if [[ "$st_pct" =~ ^([0-9]+) ]]; then
    (( BASH_REMATCH[1] >= 100 )) && st_line="${g}up to date${R}" || st_line="${y}syncing ${BASH_REMATCH[1]}%${R}"
else
    st_line="${D}(offline)${R}"
fi
printf '%s Sync%s   %s\n' "$c" "$R" "$st_line"

# --- last 10 notifications --------------------------------------------------
echo; hr
printf '%sNotifications%s\n' "$y" "$R"
hist=$(dunstctl history 2>/dev/null \
    | jq -r '.data[0][:10][] | [.appname.data, .summary.data, .body.data] | @tsv' 2>/dev/null)
if [ -n "$hist" ]; then
    while IFS=$'\t' read -r app summary body; do
        # strip pango markup, unescape common entities, collapse whitespace
        txt=$(printf '%s %s' "$summary" "$body" \
            | sed -E 's/<[^>]*>//g; s/&amp;/\&/g; s/&lt;/</g; s/&gt;/>/g; s/&#39;/'"'"'/g' \
            | tr -s ' \t' ' ')
        printf '  %s%-8.8s%s %s\n' "$g" "${app:-?}" "$R" "$(clip 37 "$txt")"
    done <<< "$hist"
else
    printf '  %s(nothing recent)%s\n' "$D" "$R"
fi
