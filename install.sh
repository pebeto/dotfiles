#!/usr/bin/env bash
# Install symlinks for this dotfiles repo. Idempotent: rerun safely.
#
#   ~/.<name>                  for each top-level entry (e.g. .zshrc)
#   ~/.config/<name>           for each entry in .config/
#   ~/.config/sway-host.conf   selects which sway/hosts/<HOST>.conf is active
#   ~/.config/foot-host.ini    selects which foot/hosts/<HOST>.ini is active
#
# Existing symlinks pointing at the right target are left alone. Existing
# files or symlinks pointing elsewhere are reported and skipped; nothing
# is overwritten unless you pass --force-host (only re-points the host
# shims, since switching profiles is the expected workflow).

set -euo pipefail

usage() {
    cat <<EOF
Usage: $(basename "$0") [--host=<name>] [--force-host] [-n|--dry-run]

  --host=<name>   Force the sway host profile (default: \$(uname -n))
  --force-host    Replace ~/.config/sway-host.conf and foot-host.ini if
                  they already point at a different host
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
SKIP=(.git .gitignore README.md docs install.sh install-macos.sh github-key-setup.sh LICENSE)

# .config/ entries that need per-file linking instead of a whole-dir
# symlink, usually because ~/.config/<name>/ already exists as a real
# dir managed by another tool (e.g. systemd creates ~/.config/systemd/).
# `omp` is special for a second reason: it reads ~/.omp/agent (not XDG), so
# its block below links files there instead of into ~/.config/omp.
CONFIG_SPECIAL=(systemd opencode omp)

skip_entry() {
    local name=$1 s
    for s in "${SKIP[@]}"; do [ "$name" = "$s" ] && return 0; done
    return 1
}

# Tool state that lands in the checkout (.opencode, .serena) is git-ignored,
# and linking it would shadow the tool's real ~/.<name>.
ignored() {
    git -C "$DOTFILES" check-ignore -q -- "$1" 2>/dev/null
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
    ignored "$entry" && continue
    [ "$name" = ".config" ] && continue
    link "$entry" "$HOME/$name"
done

echo
echo "Configs -> $CONFIG_DST"
for entry in "$DOTFILES"/.config/*; do
    name=$(basename "$entry")
    config_special "$name" && continue
    ignored "$entry" && continue
    link "$entry" "$CONFIG_DST/$name"
done

# Links into this repo whose target is gone, left behind when something was
# deleted from it (~/.config/dunst, the swaybar-era ~/.config/sway-host.sh).
echo
echo "Stale links"
for dst in "$HOME"/* "$CONFIG_DST"/*; do
    [ -L "$dst" ] && [ ! -e "$dst" ] || continue
    case "$(readlink "$dst")" in
        "$DOTFILES"/* | "$CONFIG_DST"/sway/hosts/* | "$CONFIG_DST"/foot/hosts/*) ;;
        *) continue ;;
    esac
    [ "$DRY" = 1 ] || rm "$dst"
    printf '  remove  %s (target is gone)\n' "$dst"
done
shopt -u dotglob nullglob

echo
echo "Sway host profile: $HOST"
host_conf="$DOTFILES/.config/sway/hosts/$HOST.conf"
if [ ! -f "$host_conf" ]; then
    available=$(find "$DOTFILES/.config/sway/hosts" -maxdepth 1 -name '*.conf' -printf '%f\n' 2>/dev/null | sed 's/\.conf$//' | paste -sd ', ')
    printf '  WARN    no host files for "%s" (available: %s)\n' "$HOST" "${available:-none}"
    printf '          re-run with --host=<name>\n'
    n_warn=$((n_warn + 1))
else
    force=""
    [ "$FORCE_HOST" = 1 ] && force="--force"
    link "$CONFIG_DST/sway/hosts/$HOST.conf" "$CONFIG_DST/sway-host.conf" $force
fi

# foot.ini pulls its font size from ~/.config/foot-host.ini. Kept outside the sway-host
# branch above because foot's `include` is fatal: without this link foot refuses to
# start at all, which costs you the terminal you would fix it from.
force=""
[ "$FORCE_HOST" = 1 ] && force="--force"
if [ -f "$DOTFILES/.config/foot/hosts/$HOST.ini" ]; then
    link "$CONFIG_DST/foot/hosts/$HOST.ini" "$CONFIG_DST/foot-host.ini" $force
else
    printf '  WARN    no foot/hosts/%s.ini; foot will refuse to start\n' "$HOST"
    n_warn=$((n_warn + 1))
fi

echo
echo "Systemd user units"
systemd_src="$DOTFILES/.config/systemd/user"
systemd_dst="$CONFIG_DST/systemd/user"
if [ -d "$systemd_src" ]; then
    [ "$DRY" = 1 ] || mkdir -p "$systemd_dst"
    shopt -s nullglob
    timers=()
    for unit in "$systemd_src"/*.service "$systemd_src"/*.timer; do
        name=$(basename "$unit")
        link "$unit" "$systemd_dst/$name"
        [[ "$name" == *.timer ]] && timers+=("$name")
    done
    shopt -u nullglob
    if [ "$DRY" = 0 ]; then
        systemctl --user daemon-reload 2>/dev/null || true
        # Enable+start every timer here. `|| true` because a fresh box may
        # not have a user session bus yet; re-running after login fixes it.
        [ ${#timers[@]} -gt 0 ] && systemctl --user enable --now "${timers[@]}" 2>/dev/null || true
        # Quickshell is the notification server. A dunst still installed would
        # grab the D-Bus name whenever a notification fires before Quickshell
        # is up (a timer at login, say), so it stays masked until it's removed.
        if command -v dunst >/dev/null 2>&1; then
            systemctl --user mask dunst.service >/dev/null 2>&1 || true
        fi
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
echo "omp config (per-file into ~/.omp/agent: omp keeps its auth store and session"
echo "state there too, so only the config files are linked)"
omp_src="$DOTFILES/.config/omp"
omp_dst="$HOME/.omp/agent"
if [ -d "$omp_src" ]; then
    [ "$DRY" = 1 ] || mkdir -p "$omp_dst"
    shopt -s nullglob
    for f in "$omp_src"/*.yml "$omp_src"/*.json; do
        name=$(basename "$f")
        link "$f" "$omp_dst/$name"
    done
    shopt -u nullglob
else
    printf '  WARN    %s missing\n' "$omp_src"
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
echo "Dependencies (referenced by the sway config / quickshell)"
# Arch package for each command that isn't named after it.
declare -A pkg_of=(
    [wl-copy]=wl-clipboard
    [wl-paste]=wl-clipboard [notify-send]=libnotify [wpctl]=wireplumber
    [rfkill]=util-linux [iwctl]=iwd [bluetoothctl]=bluez-utils [emacs]=emacs-wayland
)
missing=() missing_pkgs=()
for cmd in swayidle swaylock playerctl grim slurp swappy wl-copy wl-paste quickshell notify-send wpctl foot gammastep rfkill iw btop brightnessctl iwctl bluetoothctl cliphist wf-recorder jq emacs; do
    if command -v "$cmd" >/dev/null 2>&1; then
        printf '  ok      %s\n' "$cmd"
    else
        printf '  MISSING %s\n' "$cmd"
        missing+=("$cmd")
        missing_pkgs+=("${pkg_of[$cmd]:-$cmd}")
    fi
done
# The bar draws its icons from the Nerd Font symbols; sway, foot and the bar
# all set their text in JuliaMono, which only the AUR packages.
# The sway config uses swayfx's effects (blur, shadows, corners), which plain
# sway reports as errors. swayfx provides sway, swaymsg and swaynag, and only
# the AUR packages it. A leftover sway-git-debug blocks its install.
if sway --version 2>/dev/null | grep -q swayfx; then
    printf '  ok      swayfx\n'
else
    pre=""
    pacman -Q sway-git-debug >/dev/null 2>&1 && pre="sudo pacman -Rns sway-git-debug && "
    printf '  TODO    the sway config needs swayfx: %syay -S swayfx\n' "$pre"
    n_warn=$((n_warn + 1))
fi
if fc-list -q 'Symbols Nerd Font Mono'; then
    printf '  ok      Symbols Nerd Font Mono\n'
else
    printf '  MISSING Symbols Nerd Font Mono (the bar icons)\n'
    missing_pkgs+=(ttf-nerd-fonts-symbols-mono)
fi
# The launcher's emoji search reads Unicode's emoji list.
if [ -f /usr/share/unicode/emoji/emoji-test.txt ]; then
    printf '  ok      unicode-emoji\n'
else
    printf '  MISSING unicode-emoji (emoji search in the launcher)\n'
    missing_pkgs+=(unicode-emoji)
fi
if fc-list -q JuliaMono; then
    printf '  ok      JuliaMono\n'
else
    printf '  TODO    JuliaMono not installed: yay -S ttf-juliamono\n'
    n_warn=$((n_warn + 1))
fi
if command -v dunst >/dev/null 2>&1; then
    printf '  TODO    dunst is still installed; Quickshell replaced it: sudo pacman -Rns dunst\n'
    n_warn=$((n_warn + 1))
fi
# A sway reload starts Quickshell (exec_always), but a session from before the
# switch still runs dunst, which holds the notification name until it's gone.
if pgrep -x sway >/dev/null; then
    if pgrep -x dunst >/dev/null; then
        printf '  TODO    the old dunst is still running: pkill -x dunst, then reload sway (Super+Shift+c)\n'
        n_warn=$((n_warn + 1))
    elif ! pgrep -x 'quickshell|qs' >/dev/null; then
        printf '  TODO    Quickshell is not running: reload sway (Super+Shift+c) to start it\n'
        n_warn=$((n_warn + 1))
    fi
fi
# woverview isn't packaged, and the sway host configs call it by this path.
if [ -x "$HOME/.local/bin/woverview" ]; then
    printf '  ok      ~/.local/bin/woverview\n'
else
    printf '  TODO    woverview not installed, so the window overview binding does nothing:\n'
    printf "            gh release download -R pebeto/woverview -p 'woverview-*-x86_64-linux' -O ~/.local/bin/woverview && chmod +x ~/.local/bin/woverview\n"
    n_warn=$((n_warn + 1))
fi

echo
echo "Local LLM stack (.config/llm)"
# run.sh needs the workstation's GPU, and the harness configs all point at
# that server on localhost, so a machine without one skips the lot.
if ! command -v nvidia-smi >/dev/null 2>&1; then
    printf '  skip    no NVIDIA GPU on this machine\n'
else
    if command -v docker >/dev/null 2>&1; then
        printf '  ok      docker\n'
    else
        printf '  MISSING docker (run.sh serves every model through vLLM in Docker)\n'
        n_warn=$((n_warn + 1))
    fi
    if command -v omp >/dev/null 2>&1; then
        printf '  ok      omp (oh-my-pi)\n'
    else
        printf '  TODO    omp not installed: curl -fsSL https://omp.sh/install | sh\n'
    fi
fi

echo
echo "Summary: $n_link new/relinked, $n_ok already correct, $n_warn warning(s)"
if [ ${#missing[@]} -gt 0 ]; then
    echo "Missing commands: ${missing[*]}"
fi
if [ ${#missing_pkgs[@]} -gt 0 ]; then
    echo "Install them with: sudo pacman -S --needed $(printf '%s\n' "${missing_pkgs[@]}" | sort -u | paste -sd ' ')"
fi
