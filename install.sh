#!/usr/bin/env bash
# Install symlinks for this dotfiles repo. Idempotent: rerun safely.
#
#   ~/.<name>                  for each top-level entry (e.g. .zshrc)
#   ~/.config/<name>           for each entry in .config/
#   ~/.config/sway-host.conf   selects which hosts/<HOST>.conf is active
#   ~/.config/sway-host.sh     selects which hosts/<HOST>.sh is active
#
# Existing symlinks pointing at the right target are left alone. Existing
# files or symlinks pointing elsewhere are reported and skipped; nothing
# is overwritten unless you pass --force-host (only re-points the two
# sway host shims, since switching profiles is the expected workflow).

set -euo pipefail

usage() {
    cat <<EOF
Usage: $(basename "$0") [--host=<name>] [--force-host] [-n|--dry-run]

  --host=<name>   Force the sway host profile (default: \$(uname -n))
  --force-host    Replace ~/.config/sway-host.{conf,sh} if they already
                  point at a different host
  -n, --dry-run   Print what would happen, change nothing
EOF
}

HOST="$(uname -n)"
FORCE_HOST=0
DRY=0
for arg in "$@"; do
    case "$arg" in
        --host=*)        HOST="${arg#--host=}" ;;
        --force-host)    FORCE_HOST=1 ;;
        -n|--dry-run)    DRY=1 ;;
        -h|--help)       usage; exit 0 ;;
        *) echo "Unknown argument: $arg" >&2; usage >&2; exit 2 ;;
    esac
done

DOTFILES="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_DST="${XDG_CONFIG_HOME:-$HOME/.config}"

# Repo-root entries that are NOT deployed.
SKIP=(.git .gitignore README.md install.sh LICENSE)

# .config/ entries that need per-file linking instead of a whole-dir
# symlink, usually because ~/.config/<name>/ already exists as a real
# dir managed by another tool (e.g. systemd creates ~/.config/systemd/).
CONFIG_SPECIAL=(systemd opencode)

skip_entry() {
    local name=$1 s
    for s in "${SKIP[@]}"; do [ "$name" = "$s" ] && return 0; done
    return 1
}

config_special() {
    local name=$1 s
    for s in "${CONFIG_SPECIAL[@]}"; do [ "$name" = "$s" ] && return 0; done
    return 1
}

n_ok=0 n_link=0 n_warn=0

link() {
    # link <src> <dst> [--force]
    local src=$1 dst=$2 force=${3:-}
    if [ -L "$dst" ]; then
        local current; current=$(readlink "$dst")
        if [ "$current" = "$src" ]; then
            printf '  ok      %s\n' "$dst"
            n_ok=$((n_ok + 1))
            return
        fi
        if [ "$force" = "--force" ]; then
            [ "$DRY" = 1 ] || ln -sfn "$src" "$dst"
            printf '  relink  %s -> %s (was %s)\n' "$dst" "$src" "$current"
            n_link=$((n_link + 1))
            return
        fi
        printf '  WARN    %s -> %s (expected %s); use --force-host to replace\n' \
            "$dst" "$current" "$src"
        n_warn=$((n_warn + 1))
        return
    fi
    if [ -e "$dst" ]; then
        printf '  WARN    %s exists and is not a symlink; leaving alone\n' "$dst"
        n_warn=$((n_warn + 1))
        return
    fi
    [ "$DRY" = 1 ] || ln -s "$src" "$dst"
    printf '  link    %s -> %s\n' "$dst" "$src"
    n_link=$((n_link + 1))
}

echo "Dotfiles: $DOTFILES"
echo "Host:     $HOST"
[ "$DRY" = 1 ] && echo "(dry run, no changes)"
echo

[ "$DRY" = 1 ] || mkdir -p "$CONFIG_DST"

echo "Top-level dotfiles -> \$HOME"
shopt -s dotglob nullglob
for entry in "$DOTFILES"/*; do
    name=$(basename "$entry")
    skip_entry "$name" && continue
    [ "$name" = ".config" ] && continue
    link "$entry" "$HOME/$name"
done

echo
echo "Configs -> $CONFIG_DST"
for entry in "$DOTFILES"/.config/*; do
    name=$(basename "$entry")
    config_special "$name" && continue
    link "$entry" "$CONFIG_DST/$name"
done
shopt -u dotglob nullglob

echo
echo "Sway host profile: $HOST"
host_conf="$DOTFILES/.config/sway/hosts/$HOST.conf"
host_sh="$DOTFILES/.config/sway/hosts/$HOST.sh"
if [ ! -f "$host_conf" ] || [ ! -f "$host_sh" ]; then
    available=$(find "$DOTFILES/.config/sway/hosts" -maxdepth 1 -name '*.conf' -printf '%f\n' 2>/dev/null | sed 's/\.conf$//' | paste -sd ', ')
    printf '  WARN    no host files for "%s" (available: %s)\n' "$HOST" "${available:-none}"
    printf '          re-run with --host=<name>\n'
    n_warn=$((n_warn + 1))
else
    force=""
    [ "$FORCE_HOST" = 1 ] && force="--force"
    link "$CONFIG_DST/sway/hosts/$HOST.conf" "$CONFIG_DST/sway-host.conf" $force
    link "$CONFIG_DST/sway/hosts/$HOST.sh"   "$CONFIG_DST/sway-host.sh"   $force
fi

echo
echo "Systemd user units"
systemd_src="$DOTFILES/.config/systemd/user"
systemd_dst="$CONFIG_DST/systemd/user"
if [ -d "$systemd_src" ]; then
    [ "$DRY" = 1 ] || mkdir -p "$systemd_dst"
    shopt -s nullglob
    for unit in "$systemd_src"/*.service "$systemd_src"/*.timer; do
        name=$(basename "$unit")
        link "$unit" "$systemd_dst/$name"
    done
    shopt -u nullglob
    if [ "$DRY" = 0 ]; then
        systemctl --user daemon-reload 2>/dev/null || true
        # Enable+start the agenda timers. `|| true` because a fresh box may
        # not have a user session bus yet; re-running after login fixes it.
        systemctl --user enable --now agenda-refresh.timer agenda-notify.timer battery-notify.timer 2>/dev/null || true
    fi
else
    printf '  WARN    %s missing\n' "$systemd_src"
    n_warn=$((n_warn + 1))
fi

echo
echo "Opencode config (per-file: opencode itself drops bun.lock, node_modules, etc.)"
opencode_src="$DOTFILES/.config/opencode"
opencode_dst="$CONFIG_DST/opencode"
if [ -d "$opencode_src" ]; then
    [ "$DRY" = 1 ] || mkdir -p "$opencode_dst"
    shopt -s nullglob
    for f in "$opencode_src"/*.json; do
        name=$(basename "$f")
        link "$f" "$opencode_dst/$name"
    done
    shopt -u nullglob
else
    printf '  WARN    %s missing\n' "$opencode_src"
    n_warn=$((n_warn + 1))
fi

echo
echo "Misc directories"
for dir in "$HOME/Pictures/Screenshots" "$HOME/Videos/Screencasts"; do
    if [ -d "$dir" ]; then
        printf '  ok      %s\n' "$dir"
    else
        [ "$DRY" = 1 ] || mkdir -p "$dir"
        printf '  mkdir   %s\n' "$dir"
    fi
done

echo
echo "Dependencies (referenced by the sway config / barspec)"
missing=()
for cmd in sway swaymsg swayidle swaylock playerctl amixer grim slurp swappy wl-copy wl-paste dunst foot fuzzel gammastep swaynag sensors rfkill iw dunstify btop brightnessctl iwctl bluetoothctl cliphist wf-recorder jq emacs; do
    if command -v "$cmd" >/dev/null 2>&1; then
        printf '  ok      %s\n' "$cmd"
    else
        printf '  MISSING %s\n' "$cmd"
        missing+=("$cmd")
    fi
done

echo
echo "Summary: $n_link new/relinked, $n_ok already correct, $n_warn warning(s)"
if [ ${#missing[@]} -gt 0 ]; then
    echo "Missing commands: ${missing[*]}"
fi
