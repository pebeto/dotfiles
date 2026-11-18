# Coding agents

[pi](https://github.com/earendil-works/pi) is the one I use day to day, with [omp](https://github.com/can1357/oh-my-pi) and opencode as fallbacks. All three talk to the local server on port 8000 ([llm.md](llm.md)), which serves one model at a time.

## pi

`.config/pi/` has four entries. `install.sh` links them into `~/.pi/agent/`, where pi also keeps its install, auth store and sessions.

| File | Contents |
|------|----------|
| `models.json` | The `vllm` provider at `localhost:8000/v1` and the three models. `qwen3.8-pi` turns thinking off through `chat_template_kwargs` and samples at temperature 0.8 and top-p 1.0, the settings it was trained with. `qwen3.8-27b` maps pi's thinking levels onto the template's `reasoning_effort`: `low` and `medium` pass through, `high` becomes `xhigh`, and `off` disables thinking. gpt-oss takes `reasoning_effort` directly. |
| `settings.json` | Starts on `vllm/qwen3.8-pi` and limits model selection to the `vllm` models. No cloud provider is signed in. pi writes `lastChangelogVersion` here after an update, so that change can show up in the repo. |
| `AGENTS.md` | Instructions for the local model, loaded in every directory. |
| `extensions/bash-timeout.ts` | Gives every `bash` call a 300-second timeout unless the model sets its own. |

pi is the harness the LoRA was trained in. On five coding tasks with hidden tests it finished about twice as fast as omp running the same model, and ended with about half the context: its base prompt is 2.5k tokens against omp's 6.9k. It starts with four tools (read, bash, edit and write). `defaultTools` can add grep, find and ls, and MCP servers, subagents or web search come as extensions or packages when they're needed.

`AGENTS.md` is not a copy of `~/.claude/CLAUDE.md`. That file is written for Claude Code, and with it the model stopped as soon as the provided tests passed, failing a spec-driven task in 4 runs out of 6. The local version keeps the rules about scope, git, code and machine safety, drops the Claude-only parts, and tells the model to check the spec and its edge cases itself. The same task then passed 10 runs out of 12.

pi's `bash` tool waits forever when the model gives no timeout, and a test run stuck in a loop once hung a session for 20 minutes. The extension's 300 seconds matches omp's default.

## omp (oh-my-pi)

The first fallback, with subagents, LSP, web search and many more tools built in. `.config/omp/` has three files. `install.sh` links them into `~/.omp/agent/`, since omp keeps its auth and session state there instead of under XDG.

| File | Contents |
|------|----------|
| `models.yml` | The `vllm` provider at `localhost:8000/v1` with `auth: none`, the three models (Qwen, Qwen with the pi-adapted LoRA, and gpt-oss) with their real context windows, and each model's sampling settings in `compat.extraBody`, since there's no dedicated field for them. It's called `vllm` because omp v18 reserves `local` for its own on-device models. |
| `config.yml` | `modelRoles`: `plan` and `slow` use `qwen3.8-27b` with thinking, every other role uses `qwen3.8-pi`. `edit.modelVariants` gives `qwen3.8-pi` the `replace` edit tool, the string-replace format it was trained on, instead of omp's default hashline. omp rewrites this file, so it has no comments. |
| `lsp.json` | Only Julia. |

The files are small because omp finds most things on its own:

- It reads MCP servers from `~/.config/opencode/opencode.json`, so `context7` and `serena` are defined once, and editing that file changes both tools.
- It loads skills from `~/.claude/skills`, the same library Claude Code uses. It only looks one level deep, so a nested collection of skills has to be added to `skills.customDirectories`.
- It has built-in LSP setups for clangd, pyright and typescript-language-server, found through root markers and `$PATH`. Julia is the only one it doesn't know, and adding it extends the built-ins instead of replacing them.
- Every role points at the Qwen server on purpose. The GPU serves one model at a time, so a role aimed at the other model would only work while that server is running. To switch, restart `run.sh` with the other model and run `omp --model vllm/gpt-oss-20b`.

omp rewrites `config.yml` itself, from `omp config set`, `/settings` or role changes in `/models`. The change lands in the repo through the symlink and drops any comments, which is why the table above documents that file instead. `omp config path` prints the active directory. `models.yml` also sets `thinkingFormat` per model, because Qwen turns thinking on through its chat template while gpt-oss takes `reasoning_effort` directly.

## opencode

The second fallback. `.config/opencode/opencode.json` points opencode at `localhost:8000`, registers both models and defines three agents: `plan` writes a plan and can't edit code, `build` carries it out, and `research` does web search and cited answers with no code or shell access. The MCP servers are `context7` and `serena`, and LSPs are set up for Julia, C/C++, Python and TypeScript.
