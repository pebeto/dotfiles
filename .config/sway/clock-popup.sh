#!/bin/bash
# Popup for the swaybar clock, in the style of macOS Notification Center. Clicking the
# time block runs `toggle_cal_popup` (barspec-lib.sh), which renders this inside a foot
# window (app_id=cal-popup, sized by the for_window rule in sway/config). This script
# only prints styled text; the wrapper owns the window and the click-to-close.

B=$'\e[1m'; D=$'\e[2m'; R=$'\e[0m'; y=$'\e[33m'; c=$'\e[36m'; g=$'\e[32m'

# toggle_cal_popup (barspec-lib.sh) opens foot at a fixed character grid and passes its
# width in POPUP_COLS. Don't measure the terminal here instead: this shell starts before
# foot has applied the window size, so tput reports foot's 80-column default and every
# rule and notification row comes out too wide and wraps.
WIDTH=${POPUP_COLS:-48}
[[ "$WIDTH" =~ ^[0-9]+$ ]] && (( WIDTH >= 20 )) || WIDTH=48

# Append one character at a time so the rule is WIDTH glyphs whatever the locale. Both
# `printf '%.*s'` and ${str:0:n} measure bytes outside a UTF-8 locale, and each
# box-drawing character costs three of them.
LINE=''
for ((i = 0; i < WIDTH; i++)); do LINE+='─'; done

hr()   { printf '%s%s%s\n' "$D" "$LINE" "$R"; }

# Budgets in characters, which undercounts double-width glyphs: an emoji or CJK run in a
# notification renders wider than it measures. Callers leave a couple of columns spare so
# such a line still fits rather than wrapping into the next row.
clip() { local max=$1 s=$2; (( ${#s} > max )) && s="${s:0:max-1}…"; printf '%s' "$s"; }

# --- date + calendar --------------------------------------------------------
printf '%s%s%s\n\n' "$B" "$(date '+%A, %-d %B %Y')" "$R"
cal

# --- today's agenda (from the agenda-refresh timer's cache) ---
echo; hr
printf '%sAgenda%s\n' "$y" "$R"
AGENDA_NO_HEADER=1 AGENDA_COLS=$WIDTH ~/.config/sway/agenda.sh pretty

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

# Overall Syncthing completion from its REST API, with the key read out of config.xml.
# The 1s timeout keeps a stopped daemon from stalling the popup; it prints "(offline)".
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
        # 11 covers the leading indent, the app column, and the space after it
        # 11 covers the indent, the app column and its trailing space; the extra 2 are
        # slack for double-width glyphs that clip cannot measure.
        printf '  %s%-8.8s%s %s\n' "$g" "${app:-?}" "$R" "$(clip $((WIDTH - 13)) "$txt")"
    done <<< "$hist"
else
    printf '  %s(nothing recent)%s\n' "$D" "$R"
fi
