#!/bin/bash
# The org-mode agenda for the Quickshell clock panel (quickshell/services/Agenda.qml).
# Today's comes from a cache, so the panel opens with it at once: the agenda-refresh
# systemd timer runs `refresh` every few minutes. A whole month, for the days you click
# in the calendar, renders on demand in about half a second.
#
# Subcommands:
#   refresh        re-render today's agenda via emacs --batch into the cache
#   month YYYY-MM  print that month's agenda, every day under its own header

ORG_DIR="${ORG_DIR:-$HOME/Sync/orgfiles}"
CACHE_DIR="${XDG_RUNTIME_DIR:-/run/user/$(id -u)}/agenda"
CACHE_TEXT="$CACHE_DIR/today.txt"

mkdir -p "$CACHE_DIR"

# render START SPAN: the agenda over SPAN days from START (a YYYY-MM-DD, or nil for
# today), without emacs' "Day-agenda (Wxx):" or "31 days-agenda" banner.
render() {
    # -q + --no-site-file gives a deterministic env: the user's init.el isn't
    # loaded, so org's defaults apply. If you rely on custom TODO keywords or
    # agenda settings, drop -q and accept the slower start.
    emacs --batch -q --no-site-file \
        --eval "(require 'org)" \
        --eval "(require 'org-agenda)" \
        --eval "(setq org-agenda-files (directory-files \"$ORG_DIR\" t \"\\\\.org\\$\"))" \
        --eval "(setq org-agenda-skip-scheduled-if-done t
                      org-agenda-skip-deadline-if-done t
                      org-agenda-skip-timestamp-if-done t
                      org-agenda-use-time-grid nil
                      org-agenda-start-on-weekday nil)" \
        --eval "(org-agenda-list nil $1 $2)" \
        --eval "(with-current-buffer \"*Org Agenda*\"
                  (princ (buffer-substring-no-properties (point-min) (point-max))))" \
        2>/dev/null \
        | sed -e '/^\(Day\|Week\)-agenda/d' -e '/^[0-9]* days-agenda/d'
}

refresh() {
    if [ ! -d "$ORG_DIR" ]; then
        printf '(no org dir at %s)\n' "$ORG_DIR" > "$CACHE_TEXT"
        return
    fi
    # Squeeze blank-line runs.
    render nil 1 | cat -s > "$CACHE_TEXT"
}

month() {
    if ! [[ "${1:-}" =~ ^[0-9]{4}-[0-9]{2}$ ]]; then
        echo "usage: $0 month YYYY-MM" >&2
        exit 1
    fi
    if [ ! -d "$ORG_DIR" ]; then
        printf '(no org dir at %s)\n' "$ORG_DIR"
        return
    fi
    render "\"$1-01\"" "$(date -d "$1-01 +1 month -1 day" +%-d)"
}

case "$1" in
    refresh) refresh ;;
    month) month "${2:-}" ;;
    *) echo "usage: $0 refresh | month YYYY-MM" >&2; exit 1 ;;
esac
