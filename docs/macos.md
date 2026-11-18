# macOS

My work MacBook (Apple Silicon) uses the parts of this repo that make sense on a Mac: the shell, the editors, a terminal and the coding agents. The Wayland desktop and the systemd timers stay on Linux. The Mac runs gpt-oss-20b and Qwen3.8-27B locally through `llm`, and its agents can also use the workstation's server or a cloud provider.

## Install

```sh
./install-macos.sh       # symlink the Mac subset (idempotent)
./install-macos.sh -n    # preview, touch nothing
```

Like `install.sh`, it only makes symlinks and never overwrites a real file or a link that points elsewhere. It links:

| What | Where |
|------|-------|
| `.zshrc`, `.gitconfig`, `.gitignore_global` | `~/` |
| `nvim`, `emacs`, `sioyek`, `ghostty`, `swiftbar`, `bin`, `llm` | `~/.config/`, whole folders |
| `opencode/*.json` | `~/.config/opencode/`, file by file, since opencode writes its own state there |
| `omp/*.yml`, `omp/*.json` | `~/.omp/agent/`, file by file |
| `pi/*.json`, `pi/*.md`, `pi/extensions` | `~/.pi/agent/`, file by file |

Everything Linux-only is left out: `sway`, `quickshell`, `foot`, `swappy`, `systemd`, `xdg-desktop-portal-wlr` and the wallpaper. To change the set, edit the arrays at the top of the script.

It ends with a check for the command-line tools the configs expect (`nvim`, `opencode`, `omp`, `pi`, `node`, `npm`, `bun`, `uv`, `julia`, `clangd`, `pyright`, `typescript-language-server`, `git`, `gh`, `rg`, `fd`, `fzf`, `jq`, `llama-server`). It installs nothing; use Homebrew, npm or juliaup. Apps installed as casks, like Emacs or sioyek, can show as missing there even when they're in `/Applications`.

`~/.miscrc` lives outside the repo on every machine, and `.zshrc` sources it, so create a Mac one by hand for secrets and local `PATH` entries. The `llm` function in `.zshrc` runs the Mac's models on llama-server ([llm.md](llm.md#on-the-mac)).

For the GitHub key and commit signing, run `./github-key-setup.sh` after installing ([signing.md](signing.md)).

## Ghostty

Ghostty is the Mac's terminal, and `.config/ghostty/config` is the foot config translated and tuned for the 14" Retina panel:

- JuliaMono at 13 pt (`brew install --cask font-juliamono`), with commented options to thicken it if it looks too light
- the Starlight theme, with a block cursor that inverts the cell like foot's
- no padding, the native titlebar, and Ghostty quits when its last window closes
- Option works as Alt, which Emacs and Neovim need
- `F11` toggles fullscreen, as in foot

Ghostty has no inline comments: a trailing `# ...` becomes part of the value, so every comment in that file sits on its own line.

## Org agenda in the menu bar

`.config/swiftbar/agenda.5m.sh` is a SwiftBar plugin that puts today's org agenda in the menu bar, refreshed every five minutes (the `5m` in its name). The title is a calendar symbol with the number of entries, and the menu lists them, with items to refresh and to open the org folder. It renders the agenda with the same `emacs --batch` settings as the Linux side (`sway/agenda.sh`), from `~/Sync/orgfiles`.

To set it up, `brew install swiftbar emacs`, then point SwiftBar's plugin folder at `~/.config/swiftbar`.

## Microphone key

Pressing `fn+F5` mutes and unmutes the microphone instead of starting Dictation. A Karabiner-Elements rule (`.config/karabiner/mic-toggle.json`) runs `~/.config/bin/mic-toggle.sh`, which sets the input volume to 0 and back to its previous level, and posts a notification with the new state.

`install-macos.sh` doesn't link the rule, because Karabiner-Elements keeps its own `karabiner.json` in `~/.config/karabiner`. Copy `mic-toggle.json` into `~/.config/karabiner/assets/complex_modifications/`, then enable it under Complex Modifications in Karabiner's settings.

## Coding agents

pi, omp and opencode get the same config files as on Linux ([coding-agents.md](coding-agents.md)), which point at `localhost:8000`. On the Mac that means either `llm <model>` running locally or an SSH tunnel to the workstation, for example `ssh -N -L 8000:localhost:8000 <workstation>`, with a model running there. Both use port 8000, so only one can be up at a time. With neither, omp falls back to a cloud provider and asks for its API key. pi and omp start on `qwen3.8-pi`, which only the workstation serves, so with the local server pick `vllm/qwen3.8-27b` or `vllm/gpt-oss-20b` with `--model`.
