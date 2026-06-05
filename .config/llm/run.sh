#!/usr/bin/env bash
# Launch a vLLM server for one of the models defined under configs/.
# Resolves to the real script directory so it works when invoked through
# the ~/.config/llm symlink set up by dotfiles install.sh.
set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
CONFIGS_DIR="$HERE/configs"
TEMPLATES_DIR="$HERE/templates"
VERSION="${VLLM_VERSION:-v0.21.0}"
PORT="${PORT:-8000}"

list_models() {
  for f in "$CONFIGS_DIR"/*.yaml; do
    [[ -e "$f" ]] || continue
    basename "${f%.yaml}"
  done
}

usage() {
  cat >&2 <<EOF
usage: $(basename "$0") <model> [extra vllm args...]
       $(basename "$0") --list
       $(basename "$0") --update

env: VLLM_VERSION (default: nightly), PORT (default: 8000), HF_TOKEN

available models:
$(list_models | sed 's/^/  - /')
EOF
}

case "${1:-}" in
  ""|-h|--help)    usage; exit 0 ;;
  --list)          list_models; exit 0 ;;
  --update)        exec docker image pull "vllm/vllm-openai:$VERSION" ;;
esac

MODEL="$1"; shift
CONFIG="$CONFIGS_DIR/$MODEL.yaml"

if [[ ! -f "$CONFIG" ]]; then
  echo "error: no config at $CONFIG" >&2
  echo "available:" >&2
  list_models | sed 's/^/  - /' >&2
  exit 1
fi

[[ -z "${HF_TOKEN:-}" ]] && echo "warning: HF_TOKEN is not set" >&2

if command -v ss >/dev/null 2>&1 && ss -ltn 2>/dev/null | awk '{print $4}' | grep -q ":$PORT\$"; then
  echo "error: port $PORT is already in use" >&2
  exit 1
fi

exec docker run --rm -it --gpus all \
  -v ~/.cache/huggingface:/root/.cache/huggingface \
  -v ~/.cache/vllm:/root/.cache/vllm \
  -v "$TEMPLATES_DIR:/workspace/templates:ro" \
  -v "$CONFIGS_DIR:/workspace/configs:ro" \
  --env "HF_TOKEN=${HF_TOKEN:-}" \
  --env "PYTORCH_ALLOC_CONF=expandable_segments:True" \
  --env "VLLM_FLASH_ATTN_VERSION=2" \
  -p "$PORT:8000" \
  --ipc=host \
  "vllm/vllm-openai:$VERSION" \
  --config "/workspace/configs/$MODEL.yaml" \
  "$@"
