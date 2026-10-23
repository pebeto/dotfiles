# Install

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
- lists missing dependencies and prints the `pacman` command for them, or `yay` for swayfx and JuliaMono, which are only in the AUR
- warns if dunst is still installed, because it competes with Quickshell for notifications
- checks for `unicode-emoji`, the list the launcher's emoji search reads

It skips the LLM checks on machines without an NVIDIA GPU. It never overwrites a real file; it reports the conflict and moves on. `--force-host` re-points the host links when a machine changes profile.

The Mac has its own script, `install-macos.sh`, which links a smaller set. See [macos.md](macos.md).

## Moving off the swaybar setup

On a machine that was running the older swaybar version of this setup, run `pkill -x dunst` after installing, then reload sway with `Super+Shift+c`. The reload swaps the old bar for Quickshell. Idle locking keeps using swaylock until you next log in, because sway only starts swayidle at login.
