#!/usr/bin/env bash
# Launch a local llama.cpp server for one of the models defined under configs/.
#
# Each config is a flat YAML of "flag: value" pairs, translated to llama-server
# long options: `key: value` -> `--key value`, `key: true` -> `--key`,
# `key: false` -> omitted. A relative chat-template-file resolves against templates/.
#
# Resolves to the real script directory so it works through the ~/.config/llm
# symlink set up by dotfiles install.sh.
set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
CONFIGS_DIR="$HERE/configs"
TEMPLATES_DIR="$HERE/templates"
PORT="${PORT:-8000}"

list_models() {
  for f in "$CONFIGS_DIR"/*.yaml; do
    [[ -e "$f" ]] || continue
    basename "${f%.yaml}"
  done
}

usage() {
  cat >&2 <<EOF
usage: $(basename "$0") <model> [extra llama-server args...]
       $(basename "$0") --list

env: PORT (default: 8000) -- only the "already in use" check uses it;
     each config sets its own port: line.

available models:
$(list_models | sed 's/^/  - /')
EOF
}

case "${1:-}" in
  ""|-h|--help)  usage; exit 0 ;;
  --list)        list_models; exit 0 ;;
esac

MODEL="$1"; shift
CONFIG="$CONFIGS_DIR/$MODEL.yaml"

if [[ ! -f "$CONFIG" ]]; then
  echo "error: no config at $CONFIG" >&2
  echo "available:" >&2
  list_models | sed 's/^/  - /' >&2
  exit 1
fi

command -v llama-server >/dev/null 2>&1 || {
  echo "error: llama-server not found on PATH" >&2; exit 1; }

if command -v ss >/dev/null 2>&1 && ss -ltn 2>/dev/null | awk '{print $4}' | grep -q ":$PORT\$"; then
  echo "error: port $PORT is already in use" >&2
  exit 1
fi

trim() { local s=$1; s="${s#"${s%%[![:space:]]*}"}"; s="${s%"${s##*[![:space:]]}"}"; printf '%s' "$s"; }

args=()
while IFS= read -r line || [[ -n "$line" ]]; do
  line="${line%%#*}"                 # strip trailing comment
  [[ "$line" == *:* ]] || continue
  key="$(trim "${line%%:*}")"        # split on the first colon only
  val="$(trim "${line#*:}")"         # value may contain colons (e.g. repo:quant)
  [[ -z "$key" ]] && continue
  val="${val%\"}"; val="${val#\"}"   # strip one layer of surrounding quotes
  val="${val%\'}"; val="${val#\'}"
  case "$val" in
    true)  args+=("--$key") ;;
    false) ;;
    "")    args+=("--$key") ;;
    *)
      [[ "$key" == "chat-template-file" && "$val" != /* ]] && val="$TEMPLATES_DIR/$val"
      args+=("--$key" "$val")
      ;;
  esac
done < "$CONFIG"

exec llama-server "${args[@]}" "$@"
