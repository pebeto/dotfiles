# Sway

One `.config/sway/config` covers both Linux machines, and `hosts/<hostname>.conf` adds each one's outputs, inputs and hardware keys. The mod key is `Super` and the terminal is `foot`. The app launcher, the clipboard picker and the session menu are part of the Quickshell setup ([quickshell.md](quickshell.md)).

It runs on [swayfx](https://github.com/wlrfx/swayfx), sway with effects added, which installs as `sway` (`yay -S swayfx`). Tiled windows stay square and flush, with no gaps and no shadows. Floating windows and the bar's panels get rounded corners and a soft shadow, everything is solid (no blur or see-through surfaces), and windows animate when they open, move or change workspace. Plain sway reports the effect lines as config errors. If `yay` stops on `sway-git-debug` conflicting files, remove that package first.

## Hosts

Each Linux host has three pieces:

- `.config/sway/hosts/<name>.conf`: outputs, inputs, hardware keys and font size
- `.config/foot/hosts/<name>.ini`: the terminal font
- a profile in `.config/quickshell/Theme.qml`: the bar's size, colors and which blocks it shows

Font sizes differ because the workstation runs its 4K panel unscaled and the T470 doesn't. To add a machine, create the two files named after its hostname and add its profile to `Theme.qml`.

The workstation's monitor pulses in brightness with adaptive sync (VRR) on a still desktop, because the refresh rate drops between frames. Its output line leaves VRR off, and Quickshell turns it on while a window is fullscreen, like a game or a video. A host's profile opts in with `vrr`.

## Keys

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
| `Super+Shift+e` | session menu: lock, suspend, log out, restart, shut down |

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
| `Print` | region screenshot to the clipboard, with a [thumbnail](quickshell.md#screenshot-and-recording-thumbnails) to drag, edit or save |
| `XF86Display` | toggle region screen recording to `~/Videos/Screencasts`, with a thumbnail afterwards |
| `Super+Shift+v` or `XF86Favorites` | clipboard-history picker |
| `Super+Shift+p` | cycle keyboard layout (us / latam) |
| volume and mic keys | change the PipeWire default devices through `wpctl` (volume stops at 100%) and pop up a readout |
| media keys | play/pause, next and previous through `playerctl` |

## Idle and hardware keys

Sway locks the screen after five minutes idle and before suspend, and turns the screens off after ten minutes.

On the T470, the WiFi, Bluetooth and FnLock (`Fn+Esc`) keys run `indicators.sh`, which posts a notification with the new state. The laptop's embedded controller changes those states on its own, so the script only reports what happened.

## Log

Sway starts from the login shell's `sway` function in `.zshrc`, which sends its output, and that of every app it starts, to `~/.sway_log`. Each start moves the previous session's log to `~/.sway_log.old`. The `sway-log` timer checks the size every ten minutes: past 5 MiB, the last 1 MiB moves to `~/.sway_log.old` and the log starts over.
