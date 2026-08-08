# dotfiles

![wallpaper](.config/wallpaper.jpeg)

Everything it takes to turn a fresh Arch box into a usable Sway desktop: window manager, terminal, notifications, a top bar that does real work, systemd timers that keep my agenda on it, and a local LLM stack that keeps a 5090 warm. One repo, two very different machines, and zero patience for configuring the same thing twice.

## Two machines, one config

The same `~/.config` drives both of my boxes. The only thing that changes per host is a small profile under `.config/sway/hosts/`, and `install.sh` picks the right one by hostname so I never have to think about it.

| Host | What it is | Personality |
|------|-----------|-------------|
| `workstation` | The desktop with the RTX 5090 | Two screens (2560x1440@165Hz with a 1080p sidekick), black bar, brags about its GPU temperature, and runs the LLM server. Has no battery because it has never once left the desk. |
| `t470` | A ThinkPad T470 that refuses to die | TrackPoint and touchpad both wired up, brightness keys, WiFi SSID in the bar, and two batteries (the internal one plus the hot-swap pack) because ThinkPads cheat at staying alive. Gray bar, so I can tell at a glance which machine I'm yelling at. |

Each host is three files: `.config/sway/hosts/<name>.conf` for Sway outputs, inputs, hardware keys and font size, `.config/sway/hosts/<name>.sh` for the bar blocks that machine actually has, and `.config/foot/hosts/<name>.ini` for the terminal font. Font size is per host because the workstation drives a 4K panel unscaled while the T470 does not. The workstation bar shows CPU, GPU, and RAM. The T470 bar swaps in brightness, dual battery (`iBAT` for the internal pack, `eBAT` for the hot-swap one), and the WiFi network it's on. Want a third machine? Drop in two files named after its hostname and you're done.

## Install

```sh
./install.sh              # symlink everything into place (idempotent)
./install.sh --dry-run    # preview, touch nothing
./install.sh --host=t470  # force a host profile (default: this box's hostname)
```

`install.sh` links each top-level dotfile into `$HOME` and each `.config/` entry into `~/.config/`, points the Sway host shims at `hosts/<hostname>`, enables the systemd user timers, and tells you which dependencies you forgot to install. It will not clobber a real file: it reports the conflict, shrugs, and moves on. Moving to a different machine later? `--force-host` re-points the host shims and leaves everything else alone.

## Sway

A tiling Wayland session. One `config` is shared across machines; the per-host outputs, inputs, and hardware keys live in `hosts/<hostname>.conf`, which `install.sh` wires up. The mod key is `Super` (the one with the logo), the terminal is `foot`, and the launcher is `fuzzel`.

### Windows and session

| Keys | Action |
|------|--------|
| `Super+Return` | open a terminal |
| `Super+Shift+Return` | open a terminal in the focused window's directory |
| `Super+space` | app launcher |
| `Super+Shift+q` | close the focused window |
| `Super+f` | fullscreen |
| `Super+Shift+space` | toggle floating |
| `Super+Escape` | lock the screen |
| `Super+Shift+c` | reload the config |
| `Super+Shift+e` | exit Sway (asks first, because we've all rage-quit by accident) |

### Focus and move

Home-row keys `h j k l` (or the arrows) move focus; add `Shift` to drag the window along.

| Keys | Action |
|------|--------|
| `Super+h/j/k/l` | focus left/down/up/right |
| `Super+Shift+h/j/k/l` | move the window |
| `Super+a` | focus the parent container |
| hold `Super` + drag | move a floating window |

### Workspaces

| Keys | Action |
|------|--------|
| `Super+1` … `Super+0` | switch to workspace 1-10 (`0` is 10) |
| `Super+Shift+1` … `Super+Shift+0` | send the window to a workspace |

Press the current workspace's number again to bounce back to the previous one.

### Layout

| Keys | Action |
|------|--------|
| `Super+b` / `Super+v` | split horizontal / vertical |
| `Super+w` / `Super+s` | tabbed / stacking |
| `Super+e` | toggle split orientation |
| `Super+r` | resize mode (`h j k l` or arrows; `Enter` or `Esc` to leave) |
| `Super+Shift+-` / `Super+-` | send to / show the scratchpad |

### Screenshots, recording, media

| Keys | Action |
|------|--------|
| `Print` | region screenshot to the clipboard |
| `Shift+Print` | region screenshot into swappy to annotate (`Ctrl+S` saves, `Ctrl+C` copies) |
| `XF86Display` | toggle region screen recording to `~/Videos/Screencasts` |
| `XF86Favorites` | clipboard-history picker |
| `Super+Shift+p` | cycle keyboard layout (us / latam) |
| volume / media keys | wired to `amixer` and `playerctl` |

The top bar (`barspec.sh`) stacks clickable blocks and loads the host profile for whichever machine it's running on. The clock opens a calendar, the agenda block opens your schedule, and the temp/CPU block opens `btop` when you want to know exactly what's on fire. Sway locks after five minutes of idle and again before suspend, so it never sits unlocked for long.

On the T470 the bar also carries brightness, the dual-battery readout, and the WiFi SSID; its hardware keys (`XF86WLAN`, `XF86Bluetooth`, and the `Fn+Esc` FnLock toggle) fire `indicators.sh` to pop a dunst notification, since the laptop's embedded controller flips those states behind Wayland's back.

## Local LLM stack (`.config/llm`)

`run.sh` serves a local model from a per-model config in `configs/`. This is the workstation's day job. Drive it through the `llm` shell function from `.zshrc`:

```sh
llm --list             # list configured models
llm qwen3.6-27b        # main: research, general reasoning, tools (NVFP4)
llm gpt-oss-20b        # lighter reasoning + tools (MXFP4)
```

Every model is served by the official vLLM OpenAI server in Docker. Each config is flat `flag: value` YAML that becomes `vllm serve --key value`, plus three special keys (`image:`, `model:`, `env-NAME:`). One model at a time, all on port 8000.

| Model | Quant | Role |
|-------|-------|------|
| `qwen3.6-27b` | NVFP4 | **main**: research, general reasoning, coding, tools. Takes text and images at 120K context, with video disabled. Served from unsloth's compressed-tensors W4A4 build rather than NVIDIA's ModelOpt one, to stay off the Marlin kernel |
| `gpt-oss-20b` | MXFP4 | 21B MoE with 3.6B active, so it is much faster than the 27B and leaves VRAM headroom. Text only, and holds its full 131K context; reasoning depth is a per-request `reasoning_effort`. Served from OpenAI's repo, since mirrors ship a `generation_config.json` that is missing the `</call>` stop token and breaks tool calling |

Both quants are 4-bit and Blackwell-native, and both declare their format in the checkpoint, so neither config sets `--quantization`. Weights download to `~/.cache/huggingface`, which `run.sh` mounts into the container.

The Qwen model comes from unsloth rather than NVIDIA because of which kernel each one lands on. unsloth's is compressed-tensors W4A4 and runs on the native CUTLASS FP4 path. NVIDIA's is ModelOpt `MIXED_PRECISION`, whose weight-only groups have no activation scales and so fall back to Marlin, where the `EngineDeadError` crashes cluster on Blackwell (vLLM #49926, #50934, #35566). Measured here on a cold 22k-token prompt, unsloth prefills at 5,826 tok/s against 2,821 and decodes at 65.3 tok/s against 71.4. It also leaves the vision blocks and the GDN `linear_attn` layers unquantized, so its weights take 21.34 GiB instead of 20.0 and the KV pool falls to 4.31 GiB. That buys double the cold-prefill rate and no Marlin, in exchange for slower decode and 40k less context.

Video stays off (`limit-mm-per-prompt` sets `video: 0`) because profiling one video item reserves a six-figure token budget and several GiB this card does not have. Images cost at most 16,384 tokens each, which is also what caps a conversation at 7 of them.

Every client's context setting has to match its server, so `opencode.json`, `.config/omp/models.yml` and `.config/qwen/settings.json` carry 122880 for the Qwen model and 131072 for gpt-oss. After changing any of this, read `Available KV cache memory` and `GPU KV cache size` from the startup log; vLLM refuses to boot rather than quietly degrading.

Three harnesses share that one server: [omp](https://github.com/can1357/oh-my-pi) is the daily driver, opencode is the fallback, and qwen-code is Qwen's own CLI. Only one model is loaded at a time, so start the server for the model you intend to use.

### omp (oh-my-pi)

`.config/omp/` holds three files, linked into `~/.omp/agent/` by `install.sh` because omp keeps its auth store and session state in that directory rather than under XDG.

| File | Contents |
|------|----------|
| `models.yml` | The `local` provider: `localhost:8000/v1`, `auth: none`, both models with their real context windows, and per-model sampling in `compat.extraBody` (sampling has no first-class field) |
| `config.yml` | `modelRoles` (all on `qwen3.6-27b`) and `skills.customDirectories`. omp owns this file, so keep no comments in it |
| `lsp.json` | Julia only |

Each file is deliberately small, because omp discovers most of this on its own:

- **MCP servers** are read straight out of `~/.config/opencode/opencode.json`, so SearXNG, `context7` and `serena` need no second definition. Editing the opencode file changes both harnesses.
- **Skills** come from `~/.claude/skills`, the same library Claude Code uses. That discovery is one level deep, so the two nested collections (`academic-research-skills`, `claude-epub-skill`) are listed in `skills.customDirectories` to bring their 5 skills in.
- **LSP** ships built-in definitions for clangd, pyright and typescript-language-server, auto-detected from root markers and `$PATH`. Julia is the one server omp does not know, and adding it merges onto the built-ins instead of replacing them.
- **Roles** all point at the same model on purpose. One GPU serves one model, so aiming a role at the other one only works while that server happens to be running. To switch: restart `run.sh`, then `omp --model local/gpt-oss-20b`.

Two things worth knowing. omp rewrites `config.yml` itself (`omp config set`, `/settings`, role changes in `/models`), which lands in the repo through the symlink but drops any comments in the file, so document that one in this README instead; `omp config path` prints the active directory. And the thinking toggle differs per model, which is why `models.yml` sets `thinkingFormat`: Qwen wants it in the chat template, while gpt-oss takes `reasoning_effort` directly.

### opencode

Kept as the fallback for when omp misbehaves. `.config/opencode/opencode.json` points opencode at `localhost:8000`, registers both models, and defines three agents: `plan` (architect, writes the plan, can't touch code), `build` (executes it), and `research` (web search and cited Q&A, no code or shell). Web search runs through a local SearXNG instance via `one-search-mcp`; `context7` and `serena` fill out the MCP set, and LSPs are wired for Julia, C/C++, Python, and TypeScript. The scrape tools launch a Chromium at `/usr/bin/chromium`, so symlink your browser there (`install.sh` reminds you if it's missing).

### qwen-code

`.config/qwen/settings.json` points [qwen-code](https://github.com/QwenLM/qwen-code), Qwen's own CLI, at the same `localhost:8000` server and selects `qwen3.6-27b`. qwen-code reads `~/.qwen` (XDG is unsupported) and writes its own credentials and logs there, so `install.sh` links just `settings.json` into `~/.qwen/`. The rest stays out of the repo, matching how `install.sh` links opencode.

Install it with `npm install -g @qwen-code/qwen-code`, start the server with `llm qwen3.6-27b`, then run `qwen`. Two values have to line up: the model name matches what the server exposes, and `contextWindowSize` matches the server's `max-model-len`. `LOCAL_LLAMA_KEY` is a throwaway; qwen-code won't start without some API key, and the local server ignores it. Qwen3.6's reasoning and XML tool calls are parsed server-side by vLLM, so the harness needs no grammar workarounds.
