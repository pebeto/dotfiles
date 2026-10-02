#!/usr/bin/env bash
# Launch a local LLM server for one of the models defined under configs/, using the
# official vLLM OpenAI server in Docker.
#
# Each config is a flat YAML of "flag: value" pairs. Three keys are special:
#   image:        the Docker image to run (required)
#   model:        positional model_tag for `vllm serve` (required; vLLM deprecated --model)
#   env-NAME: val a Docker `-e NAME=val` (e.g. env-VLLM_*)
# Every other `key: value` becomes a `vllm serve --key value` flag, where `key: true`
# passes the bare flag and `key: false` omits it; JSON-valued flags take a quoted JSON
# object. run.sh adds the fixed docker scaffolding: --gpus all, --ipc=host, the port
# publish, the HF cache mount, and HF_TOKEN passthrough.
#
# `port:` (default 8000) both publishes the container port and drives the "already in use"
# check. `run.sh --print <model>` shows the assembled command without running it. Extra
# args after <model> are appended to the vllm command.
#
# Resolves to the real script directory so it works through the ~/.config/llm symlink
# set up by dotfiles install.sh.
set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
CONFIGS_DIR="$HERE/configs"
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

# Human-facing "  - name" listing -- used only by usage()/error output.
list_models_annotated() {
  local f
  for f in "$CONFIGS_DIR"/*.yaml; do
    [[ -e "$f" ]] || continue
    printf '  - %s\n' "$(basename "${f%.yaml}")"
  done
}

usage() {
  cat >&2 <<EOF
usage: $(basename "$0") <model> [extra vllm args...]
       $(basename "$0") --print <model>     # show the command, don't run it
       $(basename "$0") --list

Models run in Docker via the vLLM OpenAI server; \`port:\` (default 8000) drives
the in-use check. Set HF_TOKEN in the environment for gated repos.

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

PORT="$(config_get "$CONFIG" port || true)"; PORT="${PORT:-8000}"

# Port-in-use guard.
if [[ "$PRINT" -eq 0 ]] && command -v ss >/dev/null 2>&1 \
   && ss -ltn 2>/dev/null | awk '{print $4}' | grep -q ":$PORT\$"; then
  echo "error: port $PORT is already in use" >&2
  exit 1
fi

run_vllm() {
  command -v docker >/dev/null 2>&1 || {
    echo "error: docker not found on PATH (vllm engine runs in Docker)" >&2; exit 1; }
  local image="" model="" util="" serve=() denv=() line key val
  while IFS= read -r line || [[ -n "$line" ]]; do
    line="${line%%#*}"
    [[ "$line" == *:* ]] || continue
    key="$(trim "${line%%:*}")"
    val="$(trim "${line#*:}")"
    [[ -z "$key" ]] && continue
    val="${val%\"}"; val="${val#\"}"
    val="${val%\'}"; val="${val#\'}"
    case "$key" in
      engine) ;;                                   # ignored; vLLM is the only backend
      image)  image="$val" ;;                      # docker image
      model)  model="$val" ;;                      # positional model_tag (vLLM deprecated --model)
      env-*)  denv+=("-e" "${key#env-}=$val") ;;   # docker environment variable
      gpu-memory-utilization) util="$val"; serve+=("--$key" "$val") ;;
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

  # nvidia-uvm's major is allocated dynamically, so it can move between boots
  # (509 here, with nvswitch on 510). libnvidia-container sometimes creates the
  # container's /dev/nvidia-uvm on the wrong major, and CUDA then dies with
  # "CUDA unknown error" while nvidia-smi still works, since NVML never touches
  # UVM. Passing the host nodes pins the right ones.
  local uvm=()
  local d
  for d in /dev/nvidia-uvm /dev/nvidia-uvm-tools; do
    [[ -e "$d" ]] && uvm+=(--device "$d")
  done

  local docker_args=(
    run --rm --gpus all --ipc=host
    "${uvm[@]}"
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
  # vLLM samples free VRAM once at startup and aborts if it is below
  # gpu-memory-utilization x total. The desktop swings by ~0.7 GiB here, so a launch can
  # lose that race and then succeed on the next try. Wait for the headroom rather than
  # failing with a traceback 30s in.
  if [[ -n "$util" ]] && command -v nvidia-smi >/dev/null 2>&1; then
    local total need free waited=0
    total=$(nvidia-smi --query-gpu=memory.total --format=csv,noheader,nounits 2>/dev/null | head -1)
    need=$(awk -v t="${total:-0}" -v u="$util" 'BEGIN{printf "%d", t*u}')
    while [[ "$need" -gt 0 ]]; do
      free=$(nvidia-smi --query-gpu=memory.free --format=csv,noheader,nounits 2>/dev/null | head -1)
      [[ "${free:-0}" -ge "$need" ]] && break
      if [[ "$waited" -ge 60 ]]; then
        echo "error: ${free}MiB VRAM free, need ${need}MiB for gpu-memory-utilization $util" >&2
        exit 1
      fi
      [[ "$waited" -eq 0 ]] && echo "waiting for VRAM: ${free}MiB free, need ${need}MiB"
      sleep 3; waited=$((waited + 3))
    done
  fi

  exec docker "${docker_args[@]}" "$@"
}

run_vllm "$@"
