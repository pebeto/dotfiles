#!/bin/bash
# Battery warnings and history, run by battery-notify.timer every two minutes
# (mirrors the agenda-refresh systemd pair). The status bar only recolors a
# block when low; this adds a notification so you get warned when you're not
# watching the bar.
#
# Sums energy/charge across all BAT* packs, so the T470's dual internal and
# external batteries report one correct total. Each run records that total
# for the battery panel's 24-hour graph, and on battery it also says when the
# external pack is empty. A machine with no battery (e.g. the workstation)
# exits right away, so the timer is safe to enable on every host.
set -u

THRESHOLD=15   # percent; alert when discharging at or below this
SWAP=10        # percent; the external pack counts as empty at or below this

now=0 full=0 discharging=0 charging=0
for bat in /sys/class/power_supply/BAT*; do
    [ -d "$bat" ] || continue
    case "$(cat "$bat/status" 2>/dev/null)" in
    Discharging) discharging=1 ;;
    Charging) charging=1 ;;
    esac
    if [ -r "$bat/energy_now" ] && [ -r "$bat/energy_full" ]; then
        now=$((now + $(cat "$bat/energy_now")))
        full=$((full + $(cat "$bat/energy_full")))
    elif [ -r "$bat/charge_now" ] && [ -r "$bat/charge_full" ]; then
        now=$((now + $(cat "$bat/charge_now")))
        full=$((full + $(cat "$bat/charge_full")))
    fi
done

# No battery -> nothing to record or warn about.
[ "$full" -gt 0 ] 2>/dev/null || exit 0
pct=$((now * 100 / full))

# One line per run, "time percent state" (c charging, d on battery, a
# plugged in), kept for a day.
history="${XDG_STATE_HOME:-$HOME/.local/state}/battery/history.tsv"
mkdir -p "${history%/*}"
state=a
[ "$charging" -eq 1 ] && state=c
[ "$discharging" -eq 1 ] && state=d
t=$(date +%s)
{
    awk -v since=$((t - 86400)) '$1 >= since' "$history" 2>/dev/null
    printf '%s\t%s\t%s\n' "$t" "$pct" "$state"
} > "$history.new" && mv "$history.new" "$history"

# Not currently running on battery -> nothing to warn about.
[ "$discharging" -eq 1 ] || exit 0

# ThinkPads drain the external pack first. Once it's empty and the internal
# one has taken over, say so once, until a charged pack is back.
ext=/sys/class/power_supply/BAT1 int=/sys/class/power_supply/BAT0
swapped="${XDG_RUNTIME_DIR:-/tmp}/battery-swap-notified"
if [ -d "$ext" ] && [ -d "$int" ]; then
    if [ "$(cat "$ext/capacity")" -gt "$SWAP" ]; then
        rm -f "$swapped"
    elif [ "$(cat "$int/status")" = Discharging ] && [ ! -e "$swapped" ]; then
        notify-send -a "Battery" -i battery-low \
            -h "string:x-canonical-private-synchronous:battery-swap" \
            "External battery empty" "Swap it now: the internal one is at $(cat "$int/capacity")%."
        touch "$swapped"
    fi
fi

[ "$pct" -le "$THRESHOLD" ] || exit 0

# Critical urgency so it doesn't auto-expire; stack tag so repeated ticks
# replace the previous alert instead of piling up.
notify-send -a "Battery" -u critical -i battery-caution \
    -h "string:x-canonical-private-synchronous:battery-low" \
    "Battery low: ${pct}%" "Plug in soon."
