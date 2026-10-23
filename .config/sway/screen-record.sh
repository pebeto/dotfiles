#!/bin/bash
# Region screen-recording toggle, the video analogue of the screenshot
# key (screenshot.sh). First press: pick a region (slurp) and start recording to
# a timestamped file under ~/Videos/Screencasts. Second press: stop, which
# finalizes the .mp4. Bound to XF86Display (F7) in the sway config. The
# Quickshell bar shows a red dot and the elapsed time while it records.
set -u

notify() {
    # notify <icon> <body>
    command -v notify-send >/dev/null 2>&1 &&
        notify-send -a "Recording" -i "$1" \
            -h "string:x-canonical-private-synchronous:screen-record" "$2"
}

# Already recording? A SIGINT lets wf-recorder flush and close the file.
if pkill -INT -x wf-recorder; then
    qs ipc call recording stopped >/dev/null 2>&1
    notify media-playback-stop "Recording stopped"
    exit 0
fi

if ! command -v wf-recorder >/dev/null 2>&1; then
    notify dialog-error "wf-recorder is not installed"
    exit 1
fi

region=$(slurp) || exit 0          # cancelled with Escape
[ -z "$region" ] && exit 0

dir="$HOME/Videos/Screencasts"
mkdir -p "$dir"
file="$dir/$(date +%Y-%m-%d_%H-%M-%S).mp4"

qs ipc call recording started >/dev/null 2>&1
# exec so the process is literally `wf-recorder`, matching the pkill above.
exec wf-recorder -g "$region" -f "$file"
