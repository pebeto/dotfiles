#!/usr/bin/env bash
# Launch a local LLM server for one of the models defined under configs/.
#
# Each config is a flat YAML of "flag: value" pairs. A config picks its backend with
# an `engine:` key (default `llamacpp` if absent):
#
#   engine: llamacpp  ->  llama-server --key value      (key: true -> --key,
#                         key: false -> omitted). A relative chat-template-file
#                         resolves against templates/.
#
#   engine: vllm      ->  the official vLLM OpenAI server, in Docker. Special keys:
#                           image:        the Docker image to run (required)
#                           model:        positional model_tag for `vllm serve`
#                                         (required; vLLM deprecated --model)
#                           env-NAME: val a Docker `-e NAME=val` (e.g. env-VLLM_*)
#                         every other `key: value` becomes a `vllm serve --key value`
#                         flag (same true/false rules; JSON-valued flags like
#                         limit-mm-per-prompt take a quoted JSON object). run.sh adds the
#                         fixed docker scaffolding: --gpus all, --ipc=host, port publish,
#                         the HF cache mount, and HF_TOKEN passthrough.
#
# Both engines read `port:` (default 8000) for the "already in use" check; vllm also
# uses it to publish the container port. `run.sh --print <model>` shows the assembled
# command without running it. Extra args after <model> are appended to the engine cmd.
#
# Resolves to the real script directory so it works through the ~/.config/llm symlink
# set up by dotfiles install.sh.
set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
CONFIGS_DIR="$HERE/configs"
TEMPLATES_DIR="$HERE/templates"
HF_CACHE="${HF_CACHE:-$HOME/.cache/huggingface}"
PRINT=0

trim() { local s=$1; s="${s#"${s%%[![:space:]]*}"}"; s="${s%"${s##*[![:space:]]}"}"; printf '%s' "$s"; }

# config_get <file> <key> -> prints the first scalar value for <key> (quotes stripped),
# returns 1 if the key is absent. Same line/comment/quote handling as the arg parser.
config_get() {
  local file=$1 want=$2 line key val
  while IFS= read -r line || [[ -n "$line" ]]; do
    line="${line%%#*}"
    [[ "$line" == *:* ]] || continue
    key="$(trim "${line%%:*}")"
    [[ "$key" == "$want" ]] || continue
    val="$(trim "${line#*:}")"
    val="${val%\"}"; val="${val#\"}"; val="${val%\'}"; val="${val#\'}"
    printf '%s' "$val"; return 0
  done < "$file"
  return 1
}

# Plain model names, one clean name per line -- consumed by --list AND the zsh
# completion (_llm in .zshrc: `models=(${(f)"$(run.sh --list)"})` + _describe), so it
# MUST stay one bare name per line: no engine annotation, no tabs (those become part of
# the completion candidates).
list_models() {
  local f
  for f in "$CONFIGS_DIR"/*.yaml; do
    [[ -e "$f" ]] || continue
    basename "${f%.yaml}"
  done
}

# Human-facing "  - name    (engine)" listing -- used only by usage()/error output.
list_models_annotated() {
  local f name engine
  for f in "$CONFIGS_DIR"/*.yaml; do
    [[ -e "$f" ]] || continue
    name="$(basename "${f%.yaml}")"
    engine="$(config_get "$f" engine || true)"; engine="${engine:-llamacpp}"
    printf '  - %-20s (%s)\n' "$name" "$engine"
  done
}

usage() {
  cat >&2 <<EOF
usage: $(basename "$0") <model> [extra engine args...]
       $(basename "$0") --print <model>     # show the command, don't run it
       $(basename "$0") --list

Each config under configs/ selects its backend with an \`engine:\` key
(llamacpp [default] or vllm). \`port:\` (default 8000) drives the in-use check.
vllm models run in Docker; set HF_TOKEN in the environment for gated repos.

available models:
$(list_models_annotated)
EOF
}

case "${1:-}" in
  ""|-h|--help)  usage; exit 0 ;;
  --list)        list_models; exit 0 ;;
  --print|-n)    PRINT=1; shift ;;
esac

MODEL="${1:-}"; shift || true
if [[ -z "$MODEL" ]]; then usage; exit 1; fi
CONFIG="$CONFIGS_DIR/$MODEL.yaml"

if [[ ! -f "$CONFIG" ]]; then
  echo "error: no config at $CONFIG" >&2
  echo "available:" >&2
  list_models_annotated >&2
  exit 1
fi

ENGINE="$(config_get "$CONFIG" engine || true)"; ENGINE="${ENGINE:-llamacpp}"
PORT="$(config_get "$CONFIG" port || true)"; PORT="${PORT:-8000}"

# Port-in-use guard (both engines bind a host port).
if [[ "$PRINT" -eq 0 ]] && command -v ss >/dev/null 2>&1 \
   && ss -ltn 2>/dev/null | awk '{print $4}' | grep -q ":$PORT\$"; then
  echo "error: port $PORT is already in use" >&2
  exit 1
fi

run_llamacpp() {
  command -v llama-server >/dev/null 2>&1 || {
    echo "error: llama-server not found on PATH" >&2; exit 1; }
  local args=() line key val
  while IFS= read -r line || [[ -n "$line" ]]; do
    line="${line%%#*}"
    [[ "$line" == *:* ]] || continue
    key="$(trim "${line%%:*}")"
    val="$(trim "${line#*:}")"
    [[ -z "$key" ]] && continue
    [[ "$key" == "engine" ]] && continue   # dispatch key, not a llama-server flag
    val="${val%\"}"; val="${val#\"}"
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
  if [[ "$PRINT" -eq 1 ]]; then
    printf 'llama-server'; printf ' %q' "${args[@]}" "$@"; printf '\n'; exit 0
  fi
  exec llama-server "${args[@]}" "$@"
}

run_vllm() {
  command -v docker >/dev/null 2>&1 || {
    echo "error: docker not found on PATH (vllm engine runs in Docker)" >&2; exit 1; }
  local image="" model="" serve=() denv=() line key val
  while IFS= read -r line || [[ -n "$line" ]]; do
    line="${line%%#*}"
    [[ "$line" == *:* ]] || continue
    key="$(trim "${line%%:*}")"
    val="$(trim "${line#*:}")"
    [[ -z "$key" ]] && continue
    val="${val%\"}"; val="${val#\"}"
    val="${val%\'}"; val="${val#\'}"
    case "$key" in
      engine) ;;                                   # dispatch key
      image)  image="$val" ;;                      # docker image
      model)  model="$val" ;;                      # positional model_tag (vLLM deprecated --model)
      env-*)  denv+=("-e" "${key#env-}=$val") ;;   # docker environment variable
      *)
        case "$val" in
          true)  serve+=("--$key") ;;
          false) ;;
          "")    serve+=("--$key") ;;
          *)     serve+=("--$key" "$val") ;;
        esac
        ;;
    esac
  done < "$CONFIG"

  [[ -n "$image" ]] || { echo "error: vllm config $CONFIG has no 'image:' key" >&2; exit 1; }
  [[ -n "$model" ]] || { echo "error: vllm config $CONFIG has no 'model:' key" >&2; exit 1; }

  local hf=()
  [[ -n "${HF_TOKEN:-}" ]] && hf=(-e "HF_TOKEN=$HF_TOKEN")

  local docker_args=(
    run --rm --gpus all --ipc=host
    -p "${PORT}:${PORT}"
    -v "${HF_CACHE}:/root/.cache/huggingface"
    "${hf[@]}" "${denv[@]}"
    "$image"
    "$model"
    "${serve[@]}"
  )
  if [[ "$PRINT" -eq 1 ]]; then
    printf 'docker'; printf ' %q' "${docker_args[@]}" "$@"; printf '\n'; exit 0
  fi
  exec docker "${docker_args[@]}" "$@"
}

case "$ENGINE" in
  llamacpp) run_llamacpp "$@" ;;
  vllm)     run_vllm "$@" ;;
  *) echo "error: unknown engine '$ENGINE' in $CONFIG (expected: llamacpp | vllm)" >&2; exit 1 ;;
esac
