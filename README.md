# dotfiles

![wallpaper](.config/wallpaper.jpeg)

My Arch Linux desktop: Sway, the foot terminal, a Quickshell bar that also handles notifications, systemd timers that keep my org agenda on that bar, and a local LLM server for the RTX 5090. The same repo sets up both of my Linux machines, so I only configure things once, and my work MacBook takes the parts that make sense on a Mac.

## Machines

| Host | Machine | What's different |
|------|---------|------------------|
| `workstation` | Desktop with the RTX 5090 | A 4K Samsung at 144 Hz, run unscaled. Black bar with CPU, GPU and RAM. Runs the LLM server. |
| `t470` | ThinkPad T470 | 1080p panel, TrackPoint and touchpad, brightness keys. Gray bar with brightness, WiFi, Bluetooth and both batteries (`i` is the internal pack, `e` the hot-swap one). |
| MacBook | Work MacBook Pro, Apple Silicon | No Sway or Quickshell. It gets the shell, the editors, a terminal and the coding agents. |

The bar colors differ so I can tell at a glance which Linux machine I'm on. Each Linux host is picked by its hostname, and [docs/sway.md](docs/sway.md#hosts) lists what each one sets and how to add another.

## Install

```sh
./install.sh              # symlink everything into place (idempotent)
./install.sh --dry-run    # preview, touch nothing
./install.sh --host=t470  # force a host profile (default: this box's hostname)
```

`install.sh` only makes symlinks, and it never overwrites a real file. It also enables the systemd user timers and prints the `pacman` and `yay` commands for whatever is missing. On the Mac, run `./install-macos.sh` instead.

## Docs

| Doc | What's in it |
|-----|--------------|
| [install.md](docs/install.md) | What `install.sh` checks and links, and moving a machine off the old swaybar setup |
| [sway.md](docs/sway.md) | swayfx, the per-host files and every key binding |
| [quickshell.md](docs/quickshell.md) | The bar and its panels, the launcher, screenshots, notifications and the lock screen |
| [llm.md](docs/llm.md) | The vLLM server on the workstation, its models and the reasons behind the Qwen config |
| [coding-agents.md](docs/coding-agents.md) | omp and opencode, the two tools that use that server |
| [macos.md](docs/macos.md) | What the MacBook gets from this repo and how to set it up |
| [signing.md](docs/signing.md) | The per-device SSH key that does both GitHub auth and commit signing |
| [vim2emacs.md](docs/vim2emacs.md) | A guide for moving from the Neovim config to Emacs |
