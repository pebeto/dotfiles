"""Turn, tool and token counts for one pi or omp session file (both write the same format)."""
import json
import sys

turns = tools = thinking = out_tokens = last_input = 0
for line in open(sys.argv[1]):
    try:
        entry = json.loads(line)
    except json.JSONDecodeError:
        continue
    message = entry.get("message") or {}
    if message.get("role") != "assistant":
        continue
    turns += 1
    parts = message.get("content")
    if not isinstance(parts, list):
        parts = []
    tools += sum(p.get("type") == "toolCall" for p in parts)
    thinking += sum(p.get("type") == "thinking" for p in parts)
    usage = message.get("usage") or {}
    out_tokens += usage.get("output", 0)
    last_input = usage.get("input", 0) or last_input
print(f"turns={turns} tools={tools} thinking_blocks={thinking} out_tokens={out_tokens} last_input={last_input}")
