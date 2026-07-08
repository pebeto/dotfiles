#!/usr/bin/env bash
# <xbar.title>Org Agenda</xbar.title>
# <xbar.version>v1.0</xbar.version>
# <xbar.author>Jose Esparza</xbar.author>
# <xbar.desc>Today's org-mode agenda in the macOS menu bar, via emacs --batch.</xbar.desc>
# <swiftbar.hideAbout>true</swiftbar.hideAbout>
# <swiftbar.hideRunInTerminal>true</swiftbar.hideRunInTerminal>
# <swiftbar.hideLastUpdated>true</swiftbar.hideLastUpdated>
# <swiftbar.hideDisablePlugin>true</swiftbar.hideDisablePlugin>
#
# SwiftBar plugin. The "5m" in the filename = refresh every 5 minutes. It renders
# today's org agenda with the SAME `emacs --batch` invocation as the Linux swaybar
# utility (.config/sway/agenda.sh); org files sync to ~/Sync/orgfiles.
# Prereqs:  brew install swiftbar emacs
# Point SwiftBar's plugin folder at ~/.config/swiftbar (install-macos.sh symlinks it).

# SwiftBar runs plugins under launchd with a bare PATH; add Homebrew + system dirs.
export PATH="/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:$PATH"
ORG_DIR="${ORG_DIR:-$HOME/Sync/orgfiles}"

# --- guards -----------------------------------------------------------------
if ! command -v emacs >/dev/null 2>&1; then
	echo "! | sfimage=calendar.badge.exclamationmark"
	echo "---"
	echo "emacs not found on PATH | color=red"
	echo "Install it | bash=/opt/homebrew/bin/brew param1=install param2=emacs terminal=true"
	exit 0
fi
if [ ! -d "$ORG_DIR" ]; then
	echo "– | sfimage=calendar"
	echo "---"
	echo "No org dir at $ORG_DIR | color=red"
	exit 0
fi

# --- render today's agenda (same eval as .config/sway/agenda.sh) -------------
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
	              (when (get-text-property (point) 'org-marker) (setq n (1+ n)))
	              (forward-line 1))
	            (princ (format \"AGENDA_COUNT=%d\n\" n)))
	          (princ (buffer-substring-no-properties (point-min) (point-max))))" \
	2>/dev/null)

count=$(printf '%s\n' "$out" | sed -n 's/^AGENDA_COUNT=//p' | head -1)
count="${count:-0}"

# --- menu bar title: SF Symbol calendar glyph + count ------------------------
echo "$count | sfimage=calendar"
echo "---"

# Header: the agenda's date line (no leading space), tidied.
header=$(printf '%s\n' "$out" | sed -e '/^AGENDA_COUNT=/d' -e '/^\(Day\|Week\)-agenda/d' \
	| grep -m1 '^[A-Za-z]' | sed 's/  */ /g')
[ -n "$header" ] && { echo "$header | size=13"; echo "---"; }

# Entries: "category: [time] headline" -> a native menu item with an SF Symbol.
printf '%s\n' "$out" | awk '
/^[[:space:]]+[A-Za-z0-9_-]+:/ {
	line = $0
	sub(/^[[:space:]]+/, "", line)
	text = line
	sub(/^[A-Za-z0-9_-]+:[[:space:]]*/, "", text)     # drop the category prefix
	gsub(/[[:space:]]+/, " ", text)                   # squeeze org padding
	sub(/^ /, "", text); sub(/ $/, "", text)
	sym = (text ~ /[0-9][0-9]:[0-9][0-9]/) ? "clock" : "circle"
	gsub(/\|/, "\xc2\xa6", text)                      # | is SwiftBar-special
	printf "%s | sfimage=%s\n", text, sym
	seen = 1
}
END { if (!seen) print "Nothing scheduled today | color=gray sfimage=checkmark.circle" }
'

echo "---"
echo "Refresh | refresh=true sfimage=arrow.clockwise"
echo "Open org files | bash=/usr/bin/open param1=$ORG_DIR terminal=false sfimage=folder"
