#!/bin/bash
# Open a new foot in the focused foot window's current working directory
# (the deepest descendant process — typically the shell, which tracks the
# cwd the user is actually in). If the focused window isn't a foot, fall
# back to $HOME so the binding behaves like the unmodified $mod+Return.

set -u

cwd="$HOME"

focused=$(swaymsg -t get_tree -r 2>/dev/null |
          jq -r '..|objects|select(.focused==true)|"\(.pid // "")\t\(.app_id // "")"')
pid=${focused%%	*}
app=${focused##*	}

if [ "$app" = "foot" ] && [ -n "$pid" ] && [ -d "/proc/$pid" ]; then
    # BFS the process tree under foot and take the deepest descendant
    # with a readable cwd. Foot's own cwd doesn't change with `cd`; the
    # shell (or tmux's inner shell, nvim, etc.) tracks what the user is in.
    queue=("$pid")
    while [ ${#queue[@]} -gt 0 ]; do
        node=${queue[0]}; queue=("${queue[@]:1}")
        c=$(readlink -f "/proc/$node/cwd" 2>/dev/null)
        [ -n "$c" ] && [ -d "$c" ] && cwd="$c"
        for child in $(pgrep -P "$node" 2>/dev/null); do queue+=("$child"); done
    done
fi

exec foot --working-directory="$cwd"
