#!/bin/bash
# Low-battery notifier, run by battery-notify.timer (mirrors the agenda-notify
# systemd pair). The status bar only recolors a block when low; this adds a
# dunst alert so you get warned when you're not watching the bar.
#
# Sums energy/charge across all BAT* packs, so the T470's dual internal and
# external batteries report one correct total. Exits without notifying on AC
# power or on a machine with no battery (e.g. the workstation), so the timer
# is safe to enable on every host.
set -u

THRESHOLD=15   # percent; alert when discharging at or below this

now=0 full=0 discharging=0
for bat in /sys/class/power_supply/BAT*; do
    [ -d "$bat" ] || continue
    [ "$(cat "$bat/status" 2>/dev/null)" = "Discharging" ] && discharging=1
    if [ -r "$bat/energy_now" ] && [ -r "$bat/energy_full" ]; then
        now=$((now + $(cat "$bat/energy_now")))
        full=$((full + $(cat "$bat/energy_full")))
    elif [ -r "$bat/charge_now" ] && [ -r "$bat/charge_full" ]; then
        now=$((now + $(cat "$bat/charge_now")))
        full=$((full + $(cat "$bat/charge_full")))
    fi
done

# No battery, or not currently running on battery -> nothing to warn about.
[ "$full" -gt 0 ] 2>/dev/null || exit 0
[ "$discharging" -eq 1 ] || exit 0

pct=$((now * 100 / full))
[ "$pct" -le "$THRESHOLD" ] || exit 0

# Critical urgency so it doesn't auto-expire; stack tag so repeated ticks
# replace the previous alert instead of piling up.
dunstify -a "Battery" -u critical -i battery-caution \
    -h "string:x-dunst-stack-tag:battery-low" \
    "Battery low: ${pct}%" "Plug in soon."
