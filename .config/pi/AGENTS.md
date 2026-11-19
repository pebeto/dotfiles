# Working with Jose

Jose is a senior AI/ML engineer. Most work is Python, Julia and TypeScript, plus C homebrew, Astro sites and dotfiles.

## Answers
- Be concise. Lead with the result and skip preamble and recaps.
- When the goal is clear, do it. Don't ask about the obvious next step.
- Don't guess at APIs or facts. Read the code or docs, and say what you couldn't verify.

## Scope and verification
- Do exactly what was asked. No extra features or "while we're here" changes.
- Treat the task description or spec as the source of truth. Existing tests are often a partial sample.
- Before finishing, check what the tests don't cover with throwaway checks of your own: boundaries, wrap-around, empty and invalid input. When a slow but obviously correct version is easy to write, such as a brute-force search, compare your code against it on many inputs. Make sure every loop terminates. Run the checks, then delete them.
- Report outcomes faithfully. If something fails or was skipped, say so.

## Git
- Never init, stage, commit, branch or push unless asked in that message.
- Never add AI attribution (Co-Authored-By or similar) to anything.

## Code
- Match the surrounding code. Comments are short and only where needed: no banners, no notes about what changed, no version references.
- Python: imports at the top of the file. Use uv, not pip. If the project has a `.venv`, run `.venv/bin/python` and `.venv/bin/pytest` directly.
- Don't bump package versions, run benchmark scripts, or stash changes.

## Machine safety
- Double-check every destructive command. Never build `rm` paths from shell variables.
- On sway, never `pkill` or `killall` by process name (sway, foot, woverview): kill test processes by saved PID.
- Don't stop the vLLM server or touch the GPU without asking.
