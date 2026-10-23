# Coding agents

[omp](https://github.com/can1357/oh-my-pi) is the one I use day to day, and opencode is the fallback. Both talk to the local server on port 8000 ([llm.md](llm.md)), which serves one model at a time.

## omp (oh-my-pi)

`.config/omp/` has three files. `install.sh` links them into `~/.omp/agent/`, since omp keeps its auth and session state there instead of under XDG.

| File | Contents |
|------|----------|
| `models.yml` | The `vllm` provider at `localhost:8000/v1` with `auth: none`, both models with their real context windows, and each model's sampling settings in `compat.extraBody`, since there's no dedicated field for them. It's called `vllm` because omp v18 reserves `local` for its own on-device models. |
| `config.yml` | `modelRoles` (all on `qwen3.8-27b`) and `skills.customDirectories`. omp rewrites this file, so it has no comments. |
| `lsp.json` | Only Julia. |

The files are small because omp finds most things on its own:

- It reads MCP servers from `~/.config/opencode/opencode.json`, so `context7` and `serena` are defined once, and editing that file changes both tools.
- It loads skills from `~/.claude/skills`, the same library Claude Code uses. It only looks one level deep, so the two nested collections (`academic-research-skills` and `claude-epub-skill`, 5 skills between them) are listed in `skills.customDirectories`.
- It has built-in LSP setups for clangd, pyright and typescript-language-server, found through root markers and `$PATH`. Julia is the only one it doesn't know, and adding it extends the built-ins instead of replacing them.
- Every role points at the same model on purpose. The GPU serves one model at a time, so a role aimed at the other model would only work while that server is running. To switch, restart `run.sh` with the other model and run `omp --model vllm/gpt-oss-20b`.

omp rewrites `config.yml` itself, from `omp config set`, `/settings` or role changes in `/models`. The change lands in the repo through the symlink and drops any comments, which is why the table above documents that file instead. `omp config path` prints the active directory. `models.yml` also sets `thinkingFormat` per model, because Qwen turns thinking on through its chat template while gpt-oss takes `reasoning_effort` directly.

## opencode

The fallback for when omp misbehaves. `.config/opencode/opencode.json` points opencode at `localhost:8000`, registers both models and defines three agents: `plan` writes a plan and can't edit code, `build` carries it out, and `research` does web search and cited answers with no code or shell access. The MCP servers are `context7` and `serena`, and LSPs are set up for Julia, C/C++, Python and TypeScript.
