#!/bin/bash
# Region screenshot (Print): pick a region with slurp and copy the shot to
# the clipboard. Quickshell then shows it as a thumbnail in the corner, which
# you can drag into another window, click to annotate in swappy, or
# right-click to save to ~/Pictures/Screenshots. The last few shots stay in
# $XDG_RUNTIME_DIR, since a window the thumbnail was dropped on may read the
# file later (Claude Code reads it when the message is sent).
set -u

# Hide the last thumbnail so it isn't in this shot.
qs ipc call screenshot hide >/dev/null 2>&1

region=$(slurp) || exit 0          # cancelled with Escape
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
