# dotfiles

![wallpaper](.config/wallpaper.jpeg)

My Arch Linux desktop: Sway, the foot terminal, a Quickshell bar that also handles notifications, systemd timers that keep my org agenda on that bar, and a local LLM server for the RTX 5090. The same repo sets up both of my machines, so I only configure things once.

## Two machines

Both machines run the same `~/.config`. The few things that differ are picked by hostname.

| Host | Machine | What's different |
|------|---------|------------------|
| `workstation` | Desktop with the RTX 5090 | A 4K Samsung at 144 Hz, run unscaled. Black bar with CPU, GPU and RAM. Runs the LLM server. |
| `t470` | ThinkPad T470 | 1080p panel, TrackPoint and touchpad, brightness keys. Gray bar with brightness, WiFi, Bluetooth and both batteries (`i` is the internal pack, `e` the hot-swap one). |

The bar colors differ so I can tell at a glance which machine I'm on.

Each host has three pieces:

- `.config/sway/hosts/<name>.conf`: outputs, inputs, hardware keys and font size
- `.config/foot/hosts/<name>.ini`: the terminal font
- a profile in `.config/quickshell/Theme.qml`: the bar's size, colors and which blocks it shows

Font sizes differ because the workstation runs its 4K panel unscaled and the T470 doesn't. To add a machine, create the two files named after its hostname and add its profile to `Theme.qml`.

## Install

```sh
./install.sh              # symlink everything into place (idempotent)
./install.sh --dry-run    # preview, touch nothing
./install.sh --host=t470  # force a host profile (default: this box's hostname)
```

`install.sh` doesn't install packages. It:

- links each top-level dotfile into `$HOME` and each `.config/` entry into `~/.config/`
- points the sway and foot host links at this machine's files
- enables the systemd user timers
- removes links that point at files deleted from the repo
- lists missing dependencies and prints the `pacman` command for them, or `yay` for JuliaMono, which is only in the AUR
- warns if dunst is still installed, because it competes with Quickshell for notifications

It skips the LLM checks on machines without an NVIDIA GPU. It never overwrites a real file; it reports the conflict and moves on. `--force-host` re-points the host links when a machine changes profile.

On a machine that was running the older swaybar version of this setup, run `pkill -x dunst` after installing, then reload sway with `Super+Shift+c`. The reload swaps the old bar for Quickshell. Idle locking keeps using swaylock until you next log in, because sway only starts swayidle at login.

## Sway

One `config` covers both machines, and `hosts/<hostname>.conf` adds each one's outputs, inputs and hardware keys. The mod key is `Super`, the terminal is `foot` and the launcher is `fuzzel`.

### Windows and session

| Keys | Action |
|------|--------|
| `Super+Return` | open a terminal |
| `Super+Shift+Return` | open a terminal in the focused window's directory |
| `Super+space` | app launcher |
| `Super+Shift+q` | close the focused window |
| `Super+f` | fullscreen |
| `Super+Shift+space` | toggle floating |
| `Alt+space` (workstation), three-finger swipe up (T470) | window overview; the same again closes it |
| `Super+Escape` | lock the screen |
| `Super+Shift+c` | reload the config |
| `Super+Shift+e` | exit Sway (asks first) |

The window overview is [woverview](https://github.com/pebeto/woverview), another project of mine. It shows live thumbnails of every window, including the ones on other workspaces and in the scratchpad. It isn't packaged anywhere, so `install.sh` prints the command that downloads the release into `~/.local/bin`.

### Focus and move

`h j k l` or the arrow keys move focus. Add `Shift` to move the window instead.

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

Pressing the current workspace's number again goes back to the previous one.

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
| volume and mic keys | change the PipeWire default devices through `wpctl` (volume stops at 100%) and pop up a readout |
| media keys | play/pause, next and previous through `playerctl` |

Sway locks the screen after five minutes idle and before suspend.

On the T470, the WiFi, Bluetooth and FnLock (`Fn+Esc`) keys run `indicators.sh`, which posts a notification with the new state. The laptop's embedded controller changes those states on its own, so the script only reports what happened.

## Bar, notifications and lock screen (`.config/quickshell`)

The top bar, its panels, the notification popups, the lock screen and the password prompt are one Quickshell config. Sway starts it, and it reloads by itself when you edit one of its files. If it crashes, reloading sway starts it again.

- Click a workspace to switch to it, or scroll over them to step through. A workspace with an urgent window turns red, and the current binding mode (like `resize`) shows next to them.
- The clock opens a panel with a calendar, today's org agenda, what's playing (with play/pause, next and previous), the audio outputs with a volume slider, Syncthing's status and recent notifications. The agenda comes from a cache that the `agenda-refresh` timer keeps up to date. Clicking the track title brings up the player's window.
- The CPU, GPU and RAM readings turn amber and then red as they climb. Clicking them opens `btop`.
- Scroll over the volume to change it, click it to mute, and right-click it to switch outputs. On the T470, scrolling over brightness works the same way.
- On the T470, the WiFi and Bluetooth blocks open panels for joining networks (through iwd) and connecting devices. `Super+F10` opens the Bluetooth panel.
- Apps that keep running after you close their window, like Steam, get a tray icon to the left of the bell. Double-click it to open the app, right-click for its menu (drawn like the other panels), middle-click for its secondary action. Steam's icon can't open its window by itself, so the bar runs Steam's launcher instead, which brings the running copy to the front.
- The volume and mic keys, and brightness changes on the T470, pop up a readout at the bottom of the screen.
- Quickshell is also the notification server. Click a popup to close it, middle-click to run its default action, and right-click to close all of them.
- The bell turns on focus mode. Popups wait and swayidle pauses, and when you turn it off you get one "you missed N" notification.
- When something asks for admin rights through polkit (starting bluetoothd from the Bluetooth panel, `pkexec`), a password prompt opens in the middle of the screen. Quickshell is the session's polkit agent; without one, those requests fail without asking.
- You can script all of it: `qs ipc call panel toggle clock` (or `wifi`, `bluetooth`), `qs ipc call notifications toggleFocus` and `qs ipc call lock lock`. `qs ipc show` lists the rest.

The lock screen shows the wallpaper, the time and a password field on every screen. It fades in from black, and after the right password it fades down to the plain wallpaper, the same one behind your windows, before the desktop comes back. `Super+Escape`, the idle timer and suspend all go through `sway/lock.sh`, which uses swaylock instead when Quickshell isn't running. The password goes through the `login` PAM settings, so three wrong tries still lock the account for ten minutes, as before. On the T470 the lock also takes a finger on the reader, through its own PAM file (`quickshell/pam/fingerprint`), so typing the password never waits on the reader. If the reader gives up after three bad scans, press Enter on the empty field to scan again. If Quickshell crashes while the screen is locked, sway keeps it locked and blank. To get back in, switch to a TTY (`Ctrl+Alt+F2`), log in, and run:

```sh
swaymsg -s /run/user/$(id -u)/sway-ipc.$(id -u).$(pidof sway).sock exec swaylock
```

Then switch back to sway's TTY (usually `Ctrl+Alt+F1`) and unlock in swaylock.

## Local LLM stack (`.config/llm`)

The workstation also runs a local LLM server. `run.sh` starts a model from its config in `configs/`, and the `llm` function in `.zshrc` wraps it:

```sh
llm --list             # list configured models
llm qwen3.8-27b        # main: research, general reasoning, tools (NVFP4)
llm gpt-oss-20b        # lighter reasoning + tools (MXFP4)
```

Models run in the official vLLM OpenAI server in Docker, one at a time, on port 8000. Each config is flat YAML where `flag: value` becomes `vllm serve --flag value`, plus three special keys: `image:`, `model:` and `env-NAME:`. Weights download to `~/.cache/huggingface`, which `run.sh` mounts into the container.

| Model | Quant | Use |
|-------|-------|-----|
| `qwen3.8-27b` | NVFP4 | The main model: research, reasoning, coding and tools. Text and images, 128K context, no video. |
| `gpt-oss-20b` | MXFP4 | Faster and lighter (a 21B MoE with 3.6B active). Text only, 131K context, and `reasoning_effort` sets how hard it thinks per request. |

Both are 4-bit formats that Blackwell runs natively, and the checkpoints declare them, so neither config sets `--quantization`. gpt-oss comes from OpenAI's own repo because the mirrors ship a `generation_config.json` without the `</call>` stop token, which breaks tool calling.

### The Qwen config

Each setting in `configs/qwen3.8-27b.yaml` has a comment with the measurements behind it. In short:

- It uses unsloth's NVFP4 build instead of NVIDIA's ModelOpt one. NVIDIA's falls back to the Marlin kernel, which prefills at half the speed and crashes on Blackwell.
- Every client asks for `reasoning_effort: medium`. The template defaults to `xhigh`, which used about five times the tokens on six coding tasks without passing more of them, and once thought until it ran out of output budget. omp maps its `high` level to medium for this model, so only `:xhigh` asks for more; opencode sends it in `chat_template_kwargs`.
- Speculative decoding (the checkpoint's MTP layer) is off. It roughly doubles decode speed, but it caps the context at 81920 tokens, and omp then had to compact about twice as often. The config comment lists what to change to turn it back on.
- The KV cache is pinned at 4.6 GiB (139,810 tokens). Left to size itself, vLLM counts whatever the desktop allocates during startup against the cache, so the size changed from boot to boot and some boots failed.
- `TRITON_ATTN` is pinned because FlashInfer, the default, needed about 0.6 GiB more memory.
- Video is off because it needs several GiB this card doesn't have. A conversation can hold up to 8 images, since each one can cost 16,384 tokens.

Each client's context setting has to match the server, so both use 131072. After changing anything here, check `Available KV cache memory` and `GPU KV cache size` in the startup log; vLLM refuses to start if the settings don't fit.

Two tools use this server: [omp](https://github.com/can1357/oh-my-pi) day to day and opencode as a fallback. Only one model is loaded at a time, so start the one you want first.

### omp (oh-my-pi)

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

omp rewrites `config.yml` itself, from `omp config set`, `/settings` or role changes in `/models`. The change lands in the repo through the symlink and drops any comments, which is why this README documents that file instead. `omp config path` prints the active directory. `models.yml` also sets `thinkingFormat` per model, because Qwen turns thinking on through its chat template while gpt-oss takes `reasoning_effort` directly.

### opencode

The fallback for when omp misbehaves. `.config/opencode/opencode.json` points opencode at `localhost:8000`, registers both models and defines three agents: `plan` writes a plan and can't edit code, `build` carries it out, and `research` does web search and cited answers with no code or shell access. The MCP servers are `context7` and `serena`, and LSPs are set up for Julia, C/C++, Python and TypeScript.
