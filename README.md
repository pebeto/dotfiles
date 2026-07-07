# dotfiles

![wallpaper](.config/wallpaper.jpeg)

Everything it takes to turn a fresh Arch box into a usable Sway desktop: window manager, terminal, notifications, a top bar that does real work, systemd timers that nag me about my calendar, and a local LLM stack that keeps a 5090 warm. One repo, two very different machines, and zero patience for configuring the same thing twice.

## Two machines, one config

The same `~/.config` drives both of my boxes. The only thing that changes per host is a small profile under `.config/sway/hosts/`, and `install.sh` picks the right one by hostname so I never have to think about it.

| Host | What it is | Personality |
|------|-----------|-------------|
| `workstation` | The desktop with the RTX 5090 | Two screens (2560x1440@165Hz with a 1080p sidekick), black bar, brags about its GPU temperature, and runs the LLM server. Has no battery because it has never once left the desk. |
| `t470` | A ThinkPad T470 that refuses to die | TrackPoint and touchpad both wired up, brightness keys, WiFi SSID in the bar, and two batteries (the internal one plus the hot-swap pack) because ThinkPads cheat at staying alive. Gray bar, so I can tell at a glance which machine I'm yelling at. |

Each host is two files: `hosts/<name>.conf` for Sway outputs, inputs, and hardware keys, and `hosts/<name>.sh` for the bar blocks that machine actually has. The workstation bar shows CPU, GPU, and RAM. The T470 bar swaps in brightness, dual battery (`iBAT` for the internal pack, `eBAT` for the hot-swap one), and the WiFi network it's on. Want a third machine? Drop in two files named after its hostname and you're done.

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
llm devstral-small-2   # coding
llm glm-4.7-flash      # coding + thinking + tools
llm qwen3.6-27b        # research / general
```

Each config is flat `flag: value` YAML, translated to `llama-server` long options (`key: value` becomes `--key value`).

| Model | Role | Notes |
|-------|------|-------|
| `devstral-small-2` | coding agent | Mistral SWE model, grammar-constrained JSON tool calls |
| `glm-4.7-flash` | coding + reasoning agent | 30B-A3B MoE, thinking + reliable tool calls in one model |
| `qwen3.6-27b` | research / Q&A | non-thinking instruct sampler, presence penalty against over-searching |

Both serve an OpenAI-compatible API on port 8000, one at a time, and load a GGUF from `~/.cache/llama.cpp`. Pre-download the GGUF to disk first so llama.cpp memory-maps it instead of holding a live download in RAM. Skip that step and a 19 GB model pulled straight from `-hf` will OOM the box.

### opencode

`.config/opencode/opencode.json` points opencode at `localhost:8000`, registers both models, and defines four agents: `build` (Devstral, coding), `research` (Qwen3.6, web search), plus `plan` and `db`. Web search runs through a local SearXNG instance. The `one-search-mcp` scrape tools launch a Chromium at `/usr/bin/chromium`, so symlink your browser there (`install.sh` reminds you if it's missing).

### qwen-code

`.config/qwen/settings.json` points [qwen-code](https://github.com/QwenLM/qwen-code), Qwen's own CLI, at the same `localhost:8000` server and selects `qwen3.6-27b`. qwen-code reads `~/.qwen` (XDG is unsupported) and writes its own credentials and logs there, so `install.sh` links just `settings.json` into `~/.qwen/`. The rest stays out of the repo, matching how `install.sh` links opencode.

Install it with `npm install -g @qwen-code/qwen-code`, start the server with `llm qwen3.6-27b`, then run `qwen`. Two values have to line up: the provider `id` matches the server's `--alias`, and `contextWindowSize` matches the server's `ctx-size`. `LOCAL_LLAMA_KEY` is a throwaway; qwen-code won't start without some API key, and the local server ignores it.

`qwen3.6-27b` serves grammar-constrained JSON tool calls (Qwen's native XML path leaks raw `<function=...>` text that qwen-code can't execute) while `reasoning-format deepseek` splits the model's thinking into a separate field, which qwen-code shows as a "Thought" block. Both `settings.json` and the YAML use temp 0.6 for steady tool use. The YAML's bottom comment covers switching to pure no-think mode.
