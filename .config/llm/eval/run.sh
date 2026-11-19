#!/usr/bin/env bash
# Runs one coding task through a harness against the local server and grades it.
#
#   run.sh <pi|omp> <provider/model> <task> [rep] [extra harness args...]
#   run.sh pi vllm/qwen3.8-pi cron 1
#   run.sh omp vllm/qwen3.8-27b minicalc 2 --thinking high
#
# Tasks live in tasks/. After the run, tests/ is restored from the task and the cases in
# hidden/<task>/ are added, so a model that edits the tests or only satisfies the visible
# ones fails. Prints one line per run; summarize.py aggregates a file of them.
#
# Each harness gets its own agent dir under ~/.cache/llm-eval linked to the real config, so
# runs use the same models, prompt and extensions without filling the real session history.
# To try another prompt on pi, set EVAL_AGENTS_MD to its file and EVAL_TAG to a short name;
# the tag keeps that variant's agent dir and runs apart.
set -uo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
CACHE="${XDG_CACHE_HOME:-$HOME/.cache}/llm-eval"
harness=${1:?harness: pi or omp} model=${2:?model} task=${3:?task} rep=${4:-1}
shift $(( $# < 4 ? $# : 4 ))

case $task in
    durations) prompt="The tests in tests/test_durations.py fail. Find and fix the bugs in src/durations.py. Do not modify the tests. Run the tests with \`pytest\`." ;;
    invreport) prompt="Implement the change described in TASK.md. The tests in tests/ describe the expected behavior; do not modify them. Run them with \`pytest\`." ;;
    confmerge) prompt="Some tests in tests/test_config.py fail. Fix the bugs in src/appcfg without modifying the tests. Run the tests with \`pytest\`." ;;
    cron) prompt="Implement next_run in src/cronnext.py as specified in TASK.md. tests/test_cron.py has a few examples; do not modify it. Run the tests with \`pytest\`." ;;
    minicalc) prompt="Some tests in tests/test_minicalc.py fail. README.md describes how the language should behave. Fix the bugs in src/minicalc without modifying the tests. Run the tests with \`pytest\`." ;;
    *) echo "unknown task: $task" >&2; exit 2 ;;
esac

venv="$CACHE/venv"
if [ ! -x "$venv/bin/pytest" ]; then
    uv venv -q "$venv" && VIRTUAL_ENV="$venv" uv pip install -q pytest || exit 1
fi

tag=${EVAL_TAG:+-$EVAL_TAG}
agent="$CACHE/agent-$harness$tag"
mkdir -p "$agent"
case $harness in
    pi)  real="$HOME/.pi/agent"; files=(models.json settings.json mcp.json AGENTS.md extensions); cmd=(pi -p --model "$model") ;;
    omp) real="$HOME/.omp/agent"; files=(models.yml config.yml lsp.json mcp.json); cmd=(omp -p --model "$model") ;;
    *) echo "unknown harness: $harness" >&2; exit 2 ;;
esac
for f in "${files[@]}"; do
    [ -e "$real/$f" ] && ln -sfn "$(readlink -f "$real/$f")" "$agent/$f"
done
[ "$harness" = pi ] && [ -n "${EVAL_AGENTS_MD:-}" ] && ln -sfn "$(readlink -f "$EVAL_AGENTS_MD")" "$agent/AGENTS.md"

name="$harness$tag-${model//\//_}-$task-$rep"
dir="$CACHE/runs/$name"
mkdir -p "$CACHE/runs"
rm -rf -- "$dir"
cp -a "$HERE/tasks/$task" "$dir"
before=$(cd "$dir" && sha256sum tests/*.py | sha256sum)

start=$(date +%s)
(cd "$dir" && PI_CODING_AGENT_DIR="$agent" PATH="$venv/bin:$PATH" \
    timeout 1200 "${cmd[@]}" "$@" "$prompt" < /dev/null > "$dir.log" 2>&1)
code=$?
wall=$(( $(date +%s) - start ))

after=$(cd "$dir" && sha256sum tests/*.py | sha256sum)
cp -a "$HERE/tasks/$task/tests/." "$dir/tests/"
[ -d "$HERE/hidden/$task" ] && cp -a "$HERE/hidden/$task/." "$dir/tests/"
if (cd "$dir" && timeout 120 "$venv/bin/pytest" -q -p no:cacheprovider > "$dir.pytest.log" 2>&1); then
    result=PASS
else
    result=FAIL
fi
[ "$before" = "$after" ] || result="$result(tests-edited)"

session=$(ls -t "$agent"/sessions/*/*.jsonl 2>/dev/null | head -1)
stats=$([ -n "$session" ] && python3 -I "$HERE/session_stats.py" "$session")
echo "$harness$tag $model $task $rep: $result exit=$code wall=${wall}s $stats | $(tail -1 "$dir.pytest.log")"
