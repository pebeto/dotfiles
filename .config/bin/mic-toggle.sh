#!/bin/bash
# Toggle the macOS microphone on/off by flipping the system input volume.
# Bound to the mic/Dictation key via Karabiner-Elements (.config/karabiner/
# mic-toggle.json) so that key mutes the mic instead of launching Dictation.
# Remembers the pre-mute level and restores it on unmute.
STATE="${TMPDIR:-/tmp}/mic-prev-volume"

notify() { osascript -e "display notification \"$1\" with title \"Microphone\""; }

cur=$(osascript -e 'input volume of (get volume settings)' 2>/dev/null)

if [[ "$cur" =~ ^[0-9]+$ ]] && [ "$cur" -gt 0 ]; then
	printf '%s' "$cur" > "$STATE"
	osascript -e 'set volume input volume 0'
	notify "Muted"
else
	prev=$(cat "$STATE" 2>/dev/null)
	[[ "$prev" =~ ^[0-9]+$ ]] && [ "$prev" -gt 0 ] || prev=75
	osascript -e "set volume input volume $prev"
	notify "On ($prev%)"
fi
