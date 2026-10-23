#!/bin/bash
# Locks the screen with the Quickshell lock screen, or with swaylock when
# Quickshell isn't running. Returns only once every screen is covered, which
# is what swayidle's before-sleep needs before the machine suspends.
#
# `lock.sh sleep` is for before-sleep: it also tells the lock screen to let
# go of the fingerprint reader, and swayidle's after-resume hands it back.

if qs ipc call lock "${1:-lock}" >/dev/null 2>&1; then
    for _ in $(seq 1 30); do
        [ "$(qs ipc call lock secure 2>/dev/null)" = true ] && exit 0
        sleep 0.1
    done
fi
exec swaylock --font JuliaMono -l -k -f -c 000000
