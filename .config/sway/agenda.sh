#!/bin/bash
# Today's org-mode agenda, rendered into the clock popup (sway/clock-popup.sh calls
# `pretty`). `emacs --batch` is slow to cold-start, so nothing invokes it live: the
# agenda-refresh systemd timer runs `refresh` every few minutes into a cache the popup
# reads.
#
# Subcommands:
#   refresh  re-render today's agenda via emacs --batch; update cache
#   count    print today's item count (refreshes if cache is missing)
#   pretty   ANSI agenda for the popup (AGENDA_NO_HEADER=1 skips the bold day header)

ORG_DIR="${ORG_DIR:-$HOME/Sync/orgfiles}"
CACHE_DIR="${XDG_RUNTIME_DIR:-/run/user/$(id -u)}/agenda"
CACHE_TEXT="$CACHE_DIR/today.txt"
CACHE_COUNT="$CACHE_DIR/today.count"

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
    # Drop the AGENDA_COUNT marker and emacs' "Day-agenda (Wxx):" banner,
    # then squeeze blank-line runs. Cache stays plain text so count() reads it.
    printf '%s\n' "$out" \
        | sed -e '/^AGENDA_COUNT=/d' -e '/^\(Day\|Week\)-agenda/d' \
        | cat -s \
        > "$CACHE_TEXT"
    printf '%s' "${count:-0}" > "$CACHE_COUNT"
}

count() {
    [ -s "$CACHE_COUNT" ] || refresh
    cat "$CACHE_COUNT"
}

pretty() {
    [ -s "$CACHE_TEXT" ] || refresh
    # ANSI escapes are added only at display time so the cache used by
    # count stays plain text. Entries are grouped under one yellow
    # header per category instead of repeating "category:" on every line,
    # and long entries wrap with a hanging indent at the real terminal
    # width (pretty runs inside the foot popup, so tput sees it).
    local cols
    cols=$(tput cols 2>/dev/null) || cols=80
    awk -v width="${cols:-80}" -v noheader="${AGENDA_NO_HEADER:-0}" \
        -v B=$'\e[1m' -v D=$'\e[2m' -v R=$'\e[0m' \
        -v r=$'\e[31m' -v g=$'\e[32m' -v y=$'\e[33m' -v c=$'\e[36m' -v m=$'\e[35m' '
    function colorize(s) {
        gsub(/\<TODO\>/,    r "TODO" R, s)
        gsub(/\<DONE\>/,    g "DONE" R, s)
        gsub(/\<NEXT\>/,    y "NEXT" R, s)
        gsub(/\<WAITING\>/, m "WAITING" R, s)
        gsub(/Scheduled:/,  c "Scheduled:" R, s)
        gsub(/Deadline:/,   r "Deadline:" R, s)
        gsub(/[0-9][0-9]:[0-9][0-9](-[0-9][0-9]:[0-9][0-9])?/, c "&" R, s)
        return s
    }
    # Wrap at word boundaries; continuation lines align under the bullet
    # text. Wrapping happens on plain text and colorize() runs per output
    # line, so escape codes never skew the width math.
    function wrap(text, first, cont,    words, n, i, line) {
        n = split(text, words, /[ \t]+/)
        line = first words[1]
        for (i = 2; i <= n; i++) {
            if (length(line) + 1 + length(words[i]) > width) {
                print colorize(line)
                line = cont words[i]
            } else {
                line = line " " words[i]
            }
        }
        print colorize(line)
    }
    NR == 1 && /^[A-Za-z]/ {
        gsub(/  +/, " ")            # org pads the day name; tidy it
        sub(/^[A-Za-z]+/, "&,")     # "Wednesday 3 June" -> "Wednesday, 3 June"
        if (!noheader) print B $0 R
        next
    }
    /^[ \t]+[A-Za-z0-9_-]+:([ \t]|$)/ {
        line = $0
        sub(/^[ \t]+/, "", line)
        cat = line; sub(/:.*/, "", cat)
        text = line; sub(/^[A-Za-z0-9_-]+:[ \t]*/, "", text)
        if (cat != curcat) { print ""; print y cat R; curcat = cat }
        wrap(text, "  \xe2\x80\xa2 ", "    ")
        entries++
        next
    }
    /^[ \t]*$/ { next }             # grouping provides its own spacing
    { print; other++ }              # e.g. the "(no org dir at ...)" fallback
    END { if (NR && !entries && !other) print "\n" D "(nothing scheduled)" R }
    ' "$CACHE_TEXT"
}

case "$1" in
    refresh) refresh ;;
    count)   count ;;
    pretty)  pretty ;;
    *) echo "usage: $0 {refresh|count|pretty}" >&2; exit 1 ;;
esac
