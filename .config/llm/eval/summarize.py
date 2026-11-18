"""Aggregate run.sh output lines (from files or stdin) per harness, model and task."""
import collections
import fileinput
import re

LINE = re.compile(r"(\S+) (\S+) (\S+) \d+: (\S+) .*wall=(\d+)s .*out_tokens=(\d+) last_input=(\d+)")

runs = collections.defaultdict(list)
for line in fileinput.input():
    m = LINE.match(line)
    if not m:
        continue
    harness, model, task, result, wall, out, last = m.groups()
    for key in ((harness, model, task), (harness, model, "ALL")):
        runs[key].append((result == "PASS", int(wall), int(out), int(last)))

for (harness, model, task), rows in sorted(runs.items(), key=lambda kv: (kv[0][2] == "ALL", kv[0][2], kv[0][0], kv[0][1])):
    n = len(rows)
    walls = sorted(r[1] for r in rows)
    print(f"{task:10} {harness:4} {model:20} {sum(r[0] for r in rows):2}/{n:<2} pass  "
          f"median {walls[n // 2]:4}s  out {sum(r[2] for r in rows) / n:6.0f}  final context {sum(r[3] for r in rows) / n:6.0f}")
