#!/bin/bash
# Clipboard history picker: choose a past clipboard entry via fuzzel and put
# it back on the clipboard. Bound to XF86Favorites (F12).
#
# Guarded so cancelling the menu (empty selection) exits without piping an
# empty string into wl-copy, which would wipe the current clipboard. cliphist
# holds only entries copied after its wl-paste watcher started (see the
# exec_always line in the sway config).
set -u

sel=$(cliphist list | fuzzel --dmenu) || exit 0
[ -n "$sel" ] || exit 0
printf '%s\n' "$sel" | cliphist decode | wl-copy
