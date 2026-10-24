#!/bin/bash
# screenshot.sh [region|window|screen]: a screenshot copied to the
# clipboard. Print takes a region picked with slurp; the Control Center also
# asks for a window (click one) or the whole focused screen. Quickshell then
# shows the shot as a thumbnail in the corner, which you can drag into
# another window, click to annotate in swappy, or right-click to save to
# ~/Pictures/Screenshots. The last few shots stay in $XDG_RUNTIME_DIR, since
# a window the thumbnail was dropped on may read the file later (Claude Code
# reads it when the message is sent).
set -u

# Hide the last thumbnail so it isn't in this shot.
qs ipc call screenshot hide >/dev/null 2>&1

case "${1:-region}" in
window)
    # slurp offers each visible window's content area; a click picks one.
    region=$(swaymsg -t get_tree | jq -r '.. | select(.pid? and .visible?) |
        "\(.rect.x + .window_rect.x),\(.rect.y + .window_rect.y) \(.window_rect.width)x\(.window_rect.height)"' |
        slurp -r) || exit 0
    ;;
screen)
    region=$(swaymsg -t get_outputs | jq -r '.[] | select(.focused) |
        "\(.rect.x),\(.rect.y) \(.rect.width)x\(.rect.height)"')
    # The Control Center that asked is still sliding away.
    sleep 0.3
    ;;
*)
    region=$(slurp) || exit 0      # cancelled with Escape
    ;;
esac
[ -z "$region" ] && exit 0

dir="${XDG_RUNTIME_DIR:-/tmp}/screenshots"
mkdir -p "$dir"
shopt -s nullglob
old=("$dir"/screenshot-*.png)    # oldest first, by their names
(( ${#old[@]} > 4 )) && rm -f -- "${old[@]:0:${#old[@]}-4}"
file="$dir/screenshot-$(date +%Y%m%d-%H%M%S).png"
grim -g "$region" "$file" || exit 1
wl-copy --type image/png < "$file"
qs ipc call screenshot preview "$file" >/dev/null 2>&1
