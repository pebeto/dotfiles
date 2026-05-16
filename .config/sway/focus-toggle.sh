#!/bin/bash
# Toggle "focus mode": pauses dunst and freezes swayidle (no auto-lock /
# DPMS off) when ON. SIGSTOP / SIGCONT are used so swayidle's in-flight
# timers resume from where they were paused rather than restarting.
#
# State is tracked by the existence of $STATE_FILE under $XDG_RUNTIME_DIR
# (tmpfs — wiped on reboot, so focus is never persistently "on").

set -u

STATE_FILE="${XDG_RUNTIME_DIR:-/run/user/$(id -u)}/focus-mode.state"
BAR_REFRESH_FIFO="${XDG_RUNTIME_DIR:-/run/user/$(id -u)}/sway-bar-refresh"

if [ -f "$STATE_FILE" ]; then
    # Turn OFF. Count what was queued while paused, unpause, dismiss the
    # flushed queue (so the desktop isn't re-spammed), and then post a
    # single summary notification. Full content is still in `dunstctl
    # history` for later inspection.
    missed=$(dunstctl count waiting 2>/dev/null || echo 0)
    dunstctl set-paused false 2>/dev/null
    dunstctl close-all 2>/dev/null
    pkill -CONT swayidle 2>/dev/null
    rm -f "$STATE_FILE"
    if [ "${missed:-0}" -gt 0 ] 2>/dev/null; then
        dunstify -a "Focus" "Focus mode off" \
                 "You missed $missed notification$( [ "$missed" -eq 1 ] || echo s )"
    fi
else
    # Turn ON
    dunstctl set-paused true 2>/dev/null
    pkill -STOP swayidle 2>/dev/null
    : > "$STATE_FILE"
fi

# Nudge the bar to redraw the focus block immediately.
[ -p "$BAR_REFRESH_FIFO" ] && echo > "$BAR_REFRESH_FIFO" 2>/dev/null
