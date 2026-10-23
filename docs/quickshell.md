# Quickshell

The top bar and its panels, the launcher, the notification popups, the on-screen readouts, the lock screen and the polkit prompt are one Quickshell config in `.config/quickshell`. Sway starts it, and it reloads by itself when you edit one of its files. If it crashes, reloading sway (`Super+Shift+c`) starts it again.

## Bar

Workspaces sit on the left. Click one to switch to it, or scroll over them to step through. A workspace with an urgent window turns red, and the current binding mode (like `resize`) shows next to them.

The blocks on the right, in order:

| Block | What it does |
|-------|--------------|
| red dot and a timer | Shows while `XF86Display` records the screen. Click it to stop. |
| orange mic, green camera, purple screen | An app is using the microphone (its name shows), a camera, or a shared screen. The colors are the ones macOS uses. |
| tray icons | Apps that keep running after you close their window, like Steam. Double-click opens the app, right-click opens its menu, middle-click runs its secondary action. |
| bell | Focus mode, see [Notifications](#notifications). |
| keyboard | The current layout. Click to switch. |
| brain (workstation) | The local LLM server: the model it serves, or tokens per second while it generates. Click for its panel. |
| CPU, GPU, RAM | Temperatures and memory, amber and then red as they climb. Click to open `btop`. GPU is workstation-only. |
| brightness (T470) | Scroll to change it. |
| volume | Scroll to change it, click to mute, right-click to open the clock panel with the outputs. |
| batteries (T470) | `i` is the internal pack, `e` the hot-swap one. |
| WiFi, Bluetooth (T470) | Panels for joining networks (through iwd) and connecting devices. `Super+F10` opens the Bluetooth one. |
| clock | The clock panel. |

Steam's tray icon can't open its window by itself, so the bar runs Steam's launcher instead, which brings the running copy to the front.

The panels drop down from under the bar, except the clock panel, which slides in from the right. Escape or a click outside closes them.

## Clock panel

The clock opens a calendar, today's org agenda, what's playing, the sound outputs, Syncthing's status and recent notifications.

- The agenda comes from a cache that the `agenda-refresh` timer keeps up to date.
- Now playing shows the cover, the track and play/pause, next and previous. Clicking the title brings up the player's window.
- The sound section lists the outputs to switch to, a volume slider, and a slider for each app playing sound. Click an app's icon to mute it.

## LLM panel

On the workstation, the brain block's panel shows GPU memory, running requests and KV cache use, and starts, stops or switches models. The Log button opens the server's log in a terminal. A model started here runs as a systemd user unit, `llm-<model>`, so it keeps going without a terminal. [llm.md](llm.md) covers the server.

## Launcher

`Super+space` opens the app launcher, modeled on Spotlight in macOS Tahoe: a search bar fades and springs in, and grows into a list of results as you type. Arrows or Tab move, Enter picks, Escape closes. Down on an empty search lists your most used apps.

| Type | You get | Enter |
|------|---------|-------|
| an app's name | apps whose name has the letters in order, the ones you launch most first | launches it |
| `2*37`, or `=` and anything | the result | copies it |
| `:` and a name, like `:fire` | matching emoji | copies the emoji |
| `>` and a command | the command | runs it |
| `+` and a task | a TODO | adds it to `~/Sync/orgfiles/refile.org` |

The emoji search reads Unicode's own list from the `unicode-emoji` package. A captured task gets the same shape as nvim-orgmode's task template, the heading and then the day you wrote it, and a notification confirms it.

`Super+Shift+v` (or the T470's `XF86Favorites` key) opens the same bar on the clipboard history that cliphist keeps, newest first, filtered as you type. Images show as thumbnails. Picking an entry puts it back on the clipboard.

## Screenshot thumbnail

After a `Print` screenshot, a thumbnail of it sits in the bottom-right corner for a few seconds, as on macOS. It stays while the pointer is on it.

| Action | What happens |
|--------|--------------|
| drag | Drops the file into another window: foot pastes its path (so Claude Code attaches it), and a browser uploads it. |
| click | Opens it in swappy to annotate. |
| right-click | Saves it to `~/Pictures/Screenshots`. |
| middle-click | Dismisses it. |

The shots themselves stay in `$XDG_RUNTIME_DIR/screenshots`, the last five of them, so a path you dropped somewhere still works after your next screenshot.

## Notifications

Quickshell is the notification server. Click a popup to close it, middle-click to run its default action, and right-click to close all of them.

The bell turns on focus mode. Popups wait and swayidle pauses, and when you turn it off you get one "you missed N" notification.

The volume and mic keys, and brightness changes on the T470, pop up a readout at the bottom of the screen.

## Session menu and polkit

`Super+Shift+e` opens the session menu: lock, suspend, log out, restart or shut down. Arrows or the underlined letter pick one, and the last three ask first. Without Quickshell, the key falls back to swaynag.

When something asks for admin rights through polkit (starting bluetoothd from the Bluetooth panel, `pkexec`), a password prompt opens in the middle of the screen. Quickshell is the session's polkit agent; without one, those requests fail without asking.

## Lock screen

The lock screen shows the wallpaper, the time and a password field on every screen. It fades in from black, and after the right password it fades down to the plain wallpaper, the same one behind your windows, before the desktop comes back. `Super+Escape`, the idle timer and suspend all go through `sway/lock.sh`, which uses swaylock instead when Quickshell isn't running.

The password goes through the `login` PAM settings, so three wrong tries still lock the account for ten minutes. On the T470 the lock also takes a finger on the reader, through its own PAM file (`quickshell/pam/fingerprint`), so typing the password never waits on the reader. If the reader gives up after three bad scans, press Enter on the empty field to scan again.

If Quickshell crashes while the screen is locked, sway keeps it locked and blank. To get back in, switch to a TTY (`Ctrl+Alt+F2`), log in, and run:

```sh
swaymsg -s /run/user/$(id -u)/sway-ipc.$(id -u).$(pidof sway).sock exec swaylock
```

Then switch back to sway's TTY (usually `Ctrl+Alt+F1`) and unlock in swaylock.

## Scripting

Everything above answers to `qs ipc call`:

| Call | Does |
|------|------|
| `panel toggle <name>` | opens or closes `clock`, `wifi`, `bluetooth`, `llm`, `launcher`, `clipboard` or `session` |
| `notifications toggleFocus` | turns focus mode on or off |
| `lock lock` | locks the screen |
| `screenshot preview <file>` | shows a thumbnail for any image |

`qs ipc show` lists the rest. Some of them exist for the sway scripts, like `recording started` and `osd volume`.
