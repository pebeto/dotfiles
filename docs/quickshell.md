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
| brain (workstation) | The local LLM server: the model it serves, or tokens per second while it generates. Click for its panel. |
| CPU, GPU, RAM | Temperatures and memory, amber and then red as they climb. Click to open `btop`. GPU is workstation-only. |
| brightness (T470) | Scroll to change it. |
| volume | Scroll to change it, click to mute, right-click to open the Control Center with the outputs. |
| batteries (T470) | `i` is the internal pack, `e` the hot-swap one. Click for the [battery panel](#battery-panel). |
| WiFi, Bluetooth (T470) | Panels for joining networks (through iwd) and connecting devices. `Super+F10` opens the Bluetooth one. |
| two sliders | The [Control Center](#control-center). It turns into a crossed-out bell while focus mode is on ("focus") or popups are held ("held · N"). |
| clock | The clock panel. |

Steam's tray icon can't open its window by itself, so the bar runs Steam's launcher instead, which brings the running copy to the front.

The panels drop down from under the bar, except the clock panel, which slides in from the right. Escape or a click outside closes them.

## Clock panel

The clock opens a calendar, today's org agenda and recent notifications. The agenda comes from a cache that the `agenda-refresh` timer keeps up to date.

Click a day in the calendar to see its agenda instead; the Today button, or the month's title, goes back. The first day you click in a month takes about half a second, while `agenda.sh month` renders the whole month with `emacs --batch`, and the rest of that month is instant.

## Control Center

The icon next to the clock opens the quick settings, the sound, the microphone, what's playing and Syncthing.

| Tile | What it does |
|------|--------------|
| Focus | Focus mode, see [Notifications](#notifications). |
| Keep awake | Keeps the screen from locking or turning off, like focus mode, but notifications still show. |
| Night light | Pauses or resumes gammastep's warmer colors, for a game or work where the colors matter. |
| Microphone | Mutes or unmutes the default microphone. |
| Screenshot | Asks for a region, a window (click one) or the whole screen, then shows the same thumbnail as `Print`. |
| Record | Starts a region recording, the same as `XF86Display`, or stops one, showing how long it's been. |
| Layout | Switches the keyboard layout. |
| WiFi, Bluetooth (T470) | Show the network or the connected device, and open their panels. |

Right-click Focus or Keep awake to give it a time limit: 30 minutes, an hour, or until 8:00. The tile counts down, and the limit holds through a reload or a suspend. On the T470 a brightness slider follows the tiles.

- The sound section lists the outputs to switch to, a volume slider, and a slider for each app playing sound. Click an app's icon to mute it, or its name to send it to another output; a small icon shows when an app isn't on the default one. The choice lasts while that app keeps playing.
- The microphone section has the input level, and when more than one microphone is plugged in (a webcam beside the headset), the list to pick from.
- Now playing shows the cover, the track and play/pause, next and previous. Clicking the title brings up the player's window.
- Syncthing's line shows whether everything is synced and which of your other devices are connected.

Keep awake and the night light survive a reload of the shell. A night light pause lasts until gammastep itself restarts.

## Battery panel

On the T470, the battery block's panel shows:

- each pack's charge, what it's doing, its health (what it holds now against when it was new) and its cycle count
- the power draw and the time left, or the time until the charge limit while charging
- how long the internal pack lasts on its own, so you know whether to pull the external one now
- the last 24 hours of charge, colored by whether it was on battery, charging or just plugged in, with gaps where the laptop slept
- the power modes from power-profiles-daemon: Saver, Balanced and Performance
- the charge limit: stop at 80% while plugged in, and "Charge to full once" for a trip, which goes back to 80% once both packs are full

`sway/battery-notify.sh` records the history every two minutes, in `~/.local/state/battery/history.tsv`. It also sends a notification when the external pack runs empty and the internal one takes over, once per drain. The ThinkPad drains the external pack first.

The limit is the ThinkPad's own charge thresholds. Both packs get the same one, and a pack you slide in takes the internal one's. Only root can change the thresholds, so the panel needs `quickshell/udev/90-battery-charge-limit.rules`, which lets the `wheel` group change them. The power modes need power-profiles-daemon running. `install.sh` prints the commands for both.

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
| `?` and a question | an answer, written out as it streams in | copies it |
| `#` | a color picker | lets you click any pixel, then copies its hex code |

The emoji search reads Unicode's own list from the `unicode-emoji` package. A captured task gets the same shape as nvim-orgmode's task template, the heading and then the day you wrote it, and a notification confirms it.

A question goes to the local LLM server when it's serving a model, and to Claude Code otherwise. Both answer at medium effort, the setting every other client uses, and Claude Code runs with no tools or MCP servers, so a question can't make it change anything. Arrows scroll a long answer. A picked color shows up in the readout at the bottom of the screen, next to a swatch.

`Super+Shift+v` (or the T470's `XF86Favorites` key) opens the same bar on the clipboard history that cliphist keeps, newest first, filtered as you type. Images show as thumbnails. Picking an entry puts it back on the clipboard.

## Screenshot and recording thumbnails

After a `Print` screenshot or an `XF86Display` recording, a thumbnail sits in the bottom-right corner for a few seconds, as on macOS. A recording's shows a frame from its middle, a play button and its length. It stays while the pointer is on it.

| Action | Screenshot | Recording |
|--------|------------|-----------|
| drag | Drops the file into another window: foot pastes its path (so Claude Code attaches it), and a browser uploads it. | The same, with the video. |
| click | Opens it in swappy to annotate. | Plays it in your default video app, or ffplay when there's none. |
| right-click | Saves it to `~/Pictures/Screenshots`. | Moves it to the trash. |
| middle-click | Dismisses it. | Dismisses it. |

The shots themselves stay in `$XDG_RUNTIME_DIR/screenshots`, the last five of them, so a path you dropped somewhere still works after your next screenshot. Recordings live in `~/Videos/Screencasts`.

## Notifications

Quickshell is the notification server. Click a popup to close it, middle-click to run its default action, and right-click to close all of them.

Focus mode, from the Control Center, holds popups back and pauses swayidle, and when you turn it off you get one "you missed N" notification.

Popups also wait on their own while a window is fullscreen (a game, a video), while you share your screen, and while you record it, so nothing private shows up on a call or in a video. The Control Center's icon shows a crossed-out bell meanwhile, with a count once something comes in, and one summary follows when it ends.

The volume and mic keys, and brightness changes on the T470, pop up a readout at the bottom of the screen.

## Session menu and polkit

`Super+Shift+e` opens the session menu: lock, suspend, log out, restart or shut down. Arrows or the underlined letter pick one, and the last three ask first. Without Quickshell, the key falls back to swaynag.

When something asks for admin rights through polkit (starting bluetoothd from the Bluetooth panel, `pkexec`), a password prompt opens in the middle of the screen. Quickshell is the session's polkit agent; without one, those requests fail without asking.

## Lock screen

The lock screen shows the wallpaper, the time and a password field on every screen. It fades in from black, and after the right password it fades down to the plain wallpaper, the same one behind your windows, before the desktop comes back. `Super+Escape`, the idle timer and suspend all go through `sway/lock.sh`, which uses swaylock instead when Quickshell isn't running.

The password goes through the `login` PAM settings, so three wrong tries still lock the account for ten minutes. On the T470 the lock also takes a finger on the reader, through its own PAM file (`quickshell/pam/fingerprint`), so typing the password never waits on the reader. If the reader gives up after three bad scans, press Enter on the empty field to scan again.

If Quickshell crashes while the screen is locked, sway keeps the session locked and turns the screens red. Quickshell restarts itself and takes the lock back within a second or so, and the lock screen returns. It doesn't come back after a crash in its first ten seconds, or if its config changes while the screen is locked (the reload makes it exit). If the screens stay red, switch to a TTY (`Ctrl+Alt+F2`), log in, and run:

```sh
swaymsg -s /run/user/$(id -u)/sway-ipc.$(id -u).$(pidof sway).sock exec swaylock
```

Then switch back to sway's TTY (usually `Ctrl+Alt+F1`) and unlock in swaylock.

## Scripting

Everything above answers to `qs ipc call`:

| Call | Does |
|------|------|
| `panel toggle <name>` | opens or closes `clock`, `control`, `battery`, `wifi`, `bluetooth`, `llm`, `launcher`, `clipboard` or `session` |
| `notifications toggleFocus` | turns focus mode on or off |
| `lock lock` | locks the screen |
| `screenshot preview <file>` | shows a thumbnail for any image |
| `osd color <#rrggbb>` | shows a color in the readout |

`qs ipc show` lists the rest. Some of them exist for the sway scripts, like `recording started` and `osd volume`.
