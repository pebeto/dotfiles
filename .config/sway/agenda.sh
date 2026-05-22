#!/bin/bash
# Today's org-mode agenda for the swaybar, dunst notifications, and a
# click-to-toggle popup. `emacs --batch` is slow to cold-start, so the
# bar never invokes it directly — a systemd timer calls `refresh` every
# few minutes and writes two cache files; the bar just `cat`s the count.
#
# Subcommands:
#   refresh  re-render today's agenda via emacs --batch; update cache
#   count    print today's item count (refreshes if cache is missing)
#   show     toggle a foot popup showing today's full agenda
#   notify   refresh, then dunstify a summary (used by the morning timer)

ORG_DIR="${ORG_DIR:-$HOME/Sync/orgfiles}"
CACHE_DIR="${XDG_RUNTIME_DIR:-/run/user/$(id -u)}/agenda"
CACHE_TEXT="$CACHE_DIR/today.txt"
CACHE_COUNT="$CACHE_DIR/today.count"
POPUP_PID="$CACHE_DIR/popup.pid"

mkdir -p "$CACHE_DIR"

refresh() {
    if [ ! -d "$ORG_DIR" ]; then
        printf '0' > "$CACHE_COUNT"
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
                  (goto-char (point-min))
                  (let ((n 0))
                    (while (not (eobp))
                      (when (get-text-property (point) 'org-marker)
                        (setq n (1+ n)))
                      (forward-line 1))
                    (princ (format \"AGENDA_COUNT=%d\n\" n)))
                  (princ (buffer-substring-no-properties (point-min) (point-max))))" \
        2>/dev/null)

    local count
    count=$(printf '%s\n' "$out" | sed -n 's/^AGENDA_COUNT=//p' | head -1)
    printf '%s\n' "$out" | sed '/^AGENDA_COUNT=/d' > "$CACHE_TEXT"
    printf '%s' "${count:-0}" > "$CACHE_COUNT"
}

count() {
    [ -s "$CACHE_COUNT" ] || refresh
    cat "$CACHE_COUNT"
}

show() {
    if [ -f "$POPUP_PID" ] && kill -0 "$(cat "$POPUP_PID")" 2>/dev/null; then
        kill "$(cat "$POPUP_PID")" 2>/dev/null
        rm -f "$POPUP_PID"
        return
    fi
    # Always refresh on open so a popup never shows stale data — the
    # 5-min systemd cadence is too coarse for "I just edited my agenda".
    refresh
    # Same xterm mouse-tracking trick as the cal popup: any click or keypress
    # inside the foot window closes it.
    foot --app-id=agenda-popup \
         -- bash -c "cat '$CACHE_TEXT'; printf '\033[?1000h'; read -rsn1; printf '\033[?1000l'" \
         >/dev/null 2>&1 &
    echo $! > "$POPUP_PID"
}

notify() {
    refresh
    local n body
    n=$(cat "$CACHE_COUNT")
    if [ "$n" -eq 0 ] 2>/dev/null; then
        body="No items scheduled for today."
    else
        # Strip the header lines, keep only the actual entries. Cap at 10
        # so the notification stays readable.
        body=$(grep -E '^[[:space:]]+[A-Za-z0-9_-]+:' "$CACHE_TEXT" | head -10)
    fi
    dunstify -a "Agenda" -i "x-office-calendar" \
        -h "string:x-dunst-stack-tag:agenda" \
        "Agenda — $n today" "$body"
}

case "$1" in
    refresh) refresh ;;
    count)   count ;;
    show)    show ;;
    notify)  notify ;;
    *) echo "usage: $0 {refresh|count|show|notify}" >&2; exit 1 ;;
esac
