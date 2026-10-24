#!/bin/bash
# Picks the color of one pixel for the launcher's "#": click anywhere
# (slurp), and its hex code goes to the clipboard and the on-screen readout.

set -u

point=$(slurp -p) || exit 0          # cancelled with Escape
# A 1x1 PPM ends with the pixel's three bytes.
hex=$(grim -g "$point" -t ppm - | tail -c 3 | od -An -tx1 | tr -d ' \n')
[ ${#hex} -eq 6 ] || exit 1

wl-copy "#$hex"
qs ipc call osd color "#$hex" >/dev/null 2>&1 ||
    notify-send -a Color "#$hex copied"
