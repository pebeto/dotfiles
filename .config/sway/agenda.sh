#!/bin/bash
# Today's org-mode agenda. `emacs --batch` is slow to cold-start, so nothing invokes it
# live: the agenda-refresh systemd timer runs `refresh` every few minutes into a cache
# that the Quickshell clock panel reads (quickshell/services/Agenda.qml).
#
# Subcommands:
#   refresh  re-render today's agenda via emacs --batch into the cache

ORG_DIR="${ORG_DIR:-$HOME/Sync/orgfiles}"
CACHE_DIR="${XDG_RUNTIME_DIR:-/run/user/$(id -u)}/agenda"
CACHE_TEXT="$CACHE_DIR/today.txt"

mkdir -p "$CACHE_DIR"

refresh() {
    if [ ! -d "$ORG_DIR" ]; then
        printf '(no org dir at %s)\n' "$ORG_DIR" > "$CACHE_TEXT"
        return
    fi

    # -q + --no-site-file gives a deterministic env: the user's init.el isn't
    # loaded, so org's defaults apply. If you rely on custom TODO keywords or
    # agenda settings, drop -q and accept the slower start.
    local out
    out=$(emacs --batch -q --no-site-file \
        --eval "(require 'org)" \
        --eval "(require 'org-agenda)" \
        --eval "(setq org-agenda-files (directory-files \"$ORG_DIR\" t \"\\\\.org\\$\"))" \
        --eval "(setq org-agenda-skip-scheduled-if-done t
                      org-agenda-skip-deadline-if-done t
                      org-agenda-skip-timestamp-if-done t
                      org-agenda-use-time-grid nil)" \
        --eval "(org-agenda-list nil nil 1)" \
        --eval "(with-current-buffer \"*Org Agenda*\"
                  (princ (buffer-substring-no-properties (point-min) (point-max))))" \
        2>/dev/null)

    # Drop emacs' "Day-agenda (Wxx):" banner and squeeze blank-line runs.
    printf '%s\n' "$out" \
        | sed -e '/^\(Day\|Week\)-agenda/d' \
        | cat -s \
        > "$CACHE_TEXT"
}

case "$1" in
    refresh) refresh ;;
    *) echo "usage: $0 refresh" >&2; exit 1 ;;
esac
