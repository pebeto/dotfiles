#!/bin/bash
# Keeps ~/.sway_log small. sway, and every app it starts, writes there
# (the `sway` function in .zshrc), so a long session can grow it without
# end. Past 5 MiB, the last 1 MiB moves to ~/.sway_log.old and the log
# starts over; sway appends, so it keeps writing at the new end. Run by
# the sway-log timer.
set -u

log="$HOME/.sway_log"
[ -f "$log" ] || exit 0
[ "$(stat -c %s "$log")" -gt $((5 * 1024 * 1024)) ] || exit 0
tail -c $((1024 * 1024)) "$log" > "$log.old"
: > "$log"
