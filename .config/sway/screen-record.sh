#!/bin/bash
# Region screen-recording toggle, the video analogue of the screenshot
# key (screenshot.sh). First press: pick a region (slurp) and start recording to
# a timestamped file under ~/Videos/Screencasts. Second press: stop, which
# finalizes the .mp4. Bound to XF86Display (F7) in the sway config. The
# Quickshell bar shows a red dot and the elapsed time while it records, and
# afterwards the same corner thumbnail as a screenshot, with a frame from the
# middle of the video.
set -u

notify() {
    # notify <icon> <body>
    command -v notify-send >/dev/null 2>&1 &&
        notify-send -a "Recording" -i "$1" \
            -h "string:x-canonical-private-synchronous:screen-record" "$2"
}

# Already recording? A SIGINT lets wf-recorder flush and close the file.
if pkill -INT -x wf-recorder; then
    exit 0
fi

if ! command -v wf-recorder >/dev/null 2>&1; then
    notify dialog-error "wf-recorder is not installed"
    exit 1
fi

# Hide the last thumbnail so it isn't in the recording.
qs ipc call screenshot hide >/dev/null 2>&1

region=$(slurp) || exit 0          # cancelled with Escape
[ -z "$region" ] && exit 0

dir="$HOME/Videos/Screencasts"
mkdir -p "$dir"
file="$dir/$(date +%Y-%m-%d_%H-%M-%S).mp4"

qs ipc call recording started >/dev/null 2>&1
wf-recorder -g "$region" -f "$file"
qs ipc call recording stopped >/dev/null 2>&1
[ -s "$file" ] || exit 0

# A frame from the middle and the length, for the thumbnail.
frames="${XDG_RUNTIME_DIR:-/tmp}/screenshots"
mkdir -p "$frames"
rm -f "$frames"/recording-*.png
frame="$frames/recording-$(basename "$file" .mp4).png"
seconds=$(ffprobe -v error -show_entries format=duration -of csv=p=0 "$file")
ffmpeg -v error -y -ss "$(awk -v d="${seconds:-0}" 'BEGIN { print d / 2 }')" -i "$file" \
    -frames:v 1 "$frame"
qs ipc call screenshot video "$file" "$frame" \
    "$(awk -v d="${seconds:-0}" 'BEGIN { printf "%d", d + 0.5 }')" >/dev/null 2>&1
