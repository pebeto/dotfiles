#!/usr/bin/env bash
# install-macos.sh -- deploy the macOS-relevant subset of these dotfiles as symlinks.
#
# Companion to install.sh (which is Linux/sway-specific). Like install.sh, this ONLY
# creates symlinks -- it installs no packages. It deliberately links just the configs
# that are actually used on macOS; the Wayland desktop (sway/dunst/foot/fuzzel/swappy/
# xdg-desktop-portal-wlr), the systemd user units, the sway host-profile machinery, and
# the local-LLM stack (llm/) are all skipped -- none of them apply on a Mac.
#
# Edit the arrays below to match what you actually use on this Mac. Idempotent; rerun
# safely. Existing non-symlink files, or symlinks pointing elsewhere, are reported and
# left alone (never overwritten).
#
#   ./install-macos.sh [-n|--dry-run]
set -euo pipefail

[ "$(uname -s)" = "Darwin" ] || {
    echo "install-macos.sh is for macOS. On Linux use ./install.sh" >&2; exit 1; }

DOTFILES="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_DST="${XDG_CONFIG_HOME:-$HOME/.config}"

DRY=0
case "${1:-}" in
    -n|--dry-run) DRY=1 ;;
    "") ;;
    *) echo "usage: $(basename "$0") [-n|--dry-run]" >&2; exit 2 ;;
esac

# --- What to deploy on macOS (curate to taste) -----------------------------
# Top-level dotfiles          ->  ~/.<name>
TOP=( .zshrc .gitconfig )
# .config dirs (whole-dir symlink) ->  ~/.config/<name>
CONFIGS=( nvim emacs sioyek ghostty )
# Per-file *.json configs (the tool writes its own state into the dir, so link
# individual files, not the whole dir). Set to 0 to skip.
LINK_OPENCODE=1   # -> ~/.config/opencode/*.json
LINK_QWEN=1       # -> ~/.qwen/*.json  (qwen-code reads ~/.qwen, not XDG)
# ---------------------------------------------------------------------------
# Intentionally NOT linked (Linux/Wayland-only, or 5090-only):
#   dunst foot fuzzel swappy sway systemd xdg-desktop-portal-wlr llm wallpaper.jpeg
# ~/.miscrc is per-machine and lives OUTSIDE the repo -- create a Mac-specific one by
# hand (.zshrc sources it). The llm()/_llm completion in .zshrc is inert on the Mac.

n_ok=0 n_link=0 n_warn=0

link() {
    local src=$1 dst=$2 current
    if [ -L "$dst" ]; then
        current=$(readlink "$dst")
        if [ "$current" = "$src" ]; then
            printf '  ok      %s\n' "$dst"; n_ok=$((n_ok + 1)); return
        fi
        printf '  WARN    %s -> %s (expected %s); leaving alone\n' "$dst" "$current" "$src"
        n_warn=$((n_warn + 1)); return
    fi
    if [ -e "$dst" ]; then
        printf '  WARN    %s exists and is not a symlink; leaving alone\n' "$dst"
        n_warn=$((n_warn + 1)); return
    fi
    [ "$DRY" = 1 ] || ln -s "$src" "$dst"
    printf '  link    %s -> %s\n' "$dst" "$src"; n_link=$((n_link + 1))
}

echo "Dotfiles: $DOTFILES"
[ "$DRY" = 1 ] && echo "(dry run, no changes)"
[ "$DRY" = 1 ] || mkdir -p "$CONFIG_DST"

echo
echo "Top-level dotfiles -> \$HOME"
for name in "${TOP[@]}"; do
    link "$DOTFILES/$name" "$HOME/$name"
done

echo
echo "Configs -> $CONFIG_DST"
for name in "${CONFIGS[@]}"; do
    src="$DOTFILES/.config/$name"
    if [ -e "$src" ]; then
        link "$src" "$CONFIG_DST/$name"
    else
        printf '  WARN    %s missing in repo\n' "$src"; n_warn=$((n_warn + 1))
    fi
done

if [ "$LINK_OPENCODE" = 1 ]; then
    echo
    echo "opencode config (per-file *.json)"
    src="$DOTFILES/.config/opencode"; dst="$CONFIG_DST/opencode"
    [ "$DRY" = 1 ] || mkdir -p "$dst"
    shopt -s nullglob
    for f in "$src"/*.json; do link "$f" "$dst/$(basename "$f")"; done
    shopt -u nullglob
fi

if [ "$LINK_QWEN" = 1 ]; then
    echo
    echo "qwen-code config (per-file *.json into ~/.qwen)"
    src="$DOTFILES/.config/qwen"; dst="$HOME/.qwen"
    [ "$DRY" = 1 ] || mkdir -p "$dst"
    shopt -s nullglob
    for f in "$src"/*.json; do link "$f" "$dst/$(basename "$f")"; done
    shopt -u nullglob
fi

echo
echo "Dependency check (informational only -- installs nothing; use brew/npm/juliaup)"
# CLI tools the deployed configs expect. GUI-only casks (emacs/sioyek if installed as
# an .app) may show MISSING here even when present -- check /Applications for those.
for cmd in nvim opencode qwen node npm bun uv julia clangd pyright \
           typescript-language-server git gh rg fd fzf jq; do
    if command -v "$cmd" >/dev/null 2>&1; then
        printf '  ok      %s\n' "$cmd"
    else
        printf '  MISSING %s\n' "$cmd"
    fi
done

echo
printf 'Done. linked=%d ok=%d warn=%d\n' "$n_link" "$n_ok" "$n_warn"
