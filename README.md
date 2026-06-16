# dotfiles

![wallpaper](.config/wallpaper.jpeg)

Configs for an Arch + Sway workstation: window manager, terminal, notifications, systemd user timers, and a local LLM serving stack.

## Install

```sh
./install.sh             # symlink everything into place (idempotent)
./install.sh --dry-run   # preview, change nothing
```

`install.sh` links each top-level dotfile into `$HOME` and each `.config/` entry into `~/.config/`, selects the Sway host profile from `hosts/<hostname>`, enables the systemd user timers, and reports missing dependencies. It never overwrites a real file; it reports the conflict and moves on.

## Sway

A tiling Wayland session. One `config` is shared across machines; per-host outputs, inputs, and hardware keys live in `hosts/<hostname>.conf`, which `install.sh` selects. The mod key is `Super` (the logo key), the terminal is `foot`, and the launcher is `fuzzel`.

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
| `Super+Shift+e` | exit Sway (asks first) |

### Focus and move

Home-row keys `h j k l` (or the arrows) move focus; add `Shift` to move the window.

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

Pressing the current workspace's number again jumps back to the previous one.

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

The top bar (`barspec.sh`) has clickable blocks: the clock opens a calendar, the agenda block opens your schedule, and the temp/CPU block opens `btop`. Sway locks after five minutes idle and before suspend.

## Local LLM stack (`.config/llm`)

`run.sh` serves a local model from a per-model config in `configs/`. Drive it through the `llm` shell function from `.zshrc`:

```sh
llm --list             # list configured models
llm devstral-small-2   # coding
llm qwen3.6-27b        # research / general
```

Each config is flat `flag: value` YAML, translated to `llama-server` long options (`key: value` becomes `--key value`).

| Model | Role | Notes |
|-------|------|-------|
| `devstral-small-2` | coding agent | Mistral SWE model, grammar-constrained JSON tool calls |
| `qwen3.6-27b` | research / Q&A | non-thinking instruct sampler, presence penalty against over-searching |

Both serve an OpenAI-compatible API on port 8000, one at a time, and load a GGUF from `~/.cache/llama.cpp`. Pre-download the GGUF to disk first so llama.cpp memory-maps it instead of holding a live download in RAM (a 19 GB model loaded straight from `-hf` will OOM a 32 GB box).

### opencode

`.config/opencode/opencode.json` points opencode at `localhost:8000`, registers both models, and defines four agents: `build` (Devstral, coding), `research` (Qwen3.6, web search), plus `plan` and `db`. Web search runs through a local SearXNG instance. The `one-search-mcp` scrape tools launch a Chromium at `/usr/bin/chromium`; symlink your browser there (`install.sh` reminds you if it's missing).
