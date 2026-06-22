# From Neovim to Emacs

A transition guide for this repo: moving off the `nvim/` config to
`.config/emacs/`, in pure Emacs (no evil-mode). The aim is fluency in native
Emacs without a brutal first week.

Read it once top to bottom, then keep it open for the first month.

---

## The one mental shift

Vim is modal: you switch mode (`i`, `Esc`, `v`), then press unmodified keys
(`w`, `dd`, `ciw`). Emacs is modifier-based: you stay "in insert," and commands
are chords using `Control` (`C-`) and `Meta` (`M-`, the Alt key).

There's no `Esc`-to-normal reflex to retrain. Instead:

- `C-g` replaces `Esc`. It cancels the current command, prompt, or selection.
  When stuck, press `C-g`.
- You never leave insert. You press chords wherever the cursor sits.
- Sequences chain: `C-x C-f` means hold Control, press `x` then `f`.

That covers the hard part; the rest is vocabulary.

---

## Setup

1. Retire the old config. Emacs prefers `~/.emacs.d/` over the XDG path, so move
   the stale one aside:
   ```sh
   mv ~/.emacs.d ~/.emacs.d.bak
   ```
2. Symlink and launch. `./install.sh` links `.config/emacs` to
   `~/.config/emacs`. The first start downloads packages (give it a minute).
3. One-time server installs (Emacs has no `mason`, same as your nvim now):
   - LSP servers: `pyright`, `lua-language-server`, `texlab`, `clangd`,
     `typescript-language-server`
   - `M-x copilot-install-server`, then `M-x copilot-login`. Copilot stays off
     until then.
   - `M-x nerd-icons-install-fonts`.

Remap Caps Lock to Control. Emacs leans on `Control` far more than Vim, and the
default pinky reach will hurt. On your Sway box, add to a host input block:
```
input "type:keyboard" {
    xkb_options ctrl:nocaps
}
```

Run the built-in tutorial once: launch Emacs and press `C-h t`. Thirty minutes,
and it drills movement and editing.

---

## Survival kit (day one)

| Need | Keys | Notes |
|---|---|---|
| Cancel anything | `C-g` | the new `Esc` |
| Quit Emacs | `C-x C-c` | |
| Open file | `C-x C-f` | `find-file`; creates if missing |
| Save | `C-x C-s` | |
| Switch buffer | `C-x b` | fuzzy, via consult |
| Kill buffer | `C-x k` | "kill" = close |
| Undo / redo | `C-/` / `C-g` then `C-/` | undo is tree-structured |
| Split window | `C-x 2` (below) `C-x 3` (right) | |
| Move between windows | `C-x o` | other window |
| Close window / others | `C-x 0` / `C-x 1` | |
| What does this key do? | `C-h k` then the key | Emacs explains itself |
| Describe a command | `C-h f` | also `C-h v` (var), `C-h m` (mode) |
| Run a command by name | `M-x` | your config: also `C-c f a` |

`C-h` (help) is the feature that carries you. Forget a binding, and
`C-h k <keys>` names the command behind any key.

The `C-c` prefix is this config's leader, mirroring your nvim leader groups
(`f` find, `l` LSP, `g` git). Press `C-c` and wait: which-key shows the menu,
same as nvim.

---

## Vim reflex to Emacs equivalent

Translation for the operations your fingers do without thinking. Arrow keys and
`PageUp/Down` also work everywhere if you need a crutch early on.

### Motion

| Vim | Emacs | |
|---|---|---|
| `h j k l` | `C-b  C-n  C-p  C-f` | back / next-line / prev-line / forward |
| `w` / `b` | `M-f` / `M-b` | forward / back a word |
| `0` / `$` | `C-a` / `C-e` | line start / end |
| `^` | `M-m` | first non-blank |
| `gg` / `G` | `M-<` / `M->` | buffer start / end |
| `Ctrl-d` / `Ctrl-u` | `C-v` / `M-v` | page down / up |
| `%` (match), code nav | `C-M-f` / `C-M-b` | over a balanced expr (sexp) |
| `Ctrl-o` / `Ctrl-i` (jumplist) | `C-u C-SPC` / `M-,` | pop local mark / pop back after a jump |
| `{` `}` paragraph | `M-{` `M-}` | |

### Editing

| Vim | Emacs | |
|---|---|---|
| `x` | `C-d` | delete char |
| `dw` | `M-d` | kill word forward (`M-DEL` = backward) |
| `dd` | `C-S-DEL` | kill whole line |
| `D` / `C` | `C-k` | kill to end of line |
| `p` | `C-y` | yank (paste) |
| after paste, cycle | `M-y` | walk the kill-ring, no registers needed |
| `yy` then paste | `C-a C-SPC C-e M-w` | mark the line, then copy |
| `v` then motion | `C-SPC` then motion | set mark, then move for a region |
| `Ctrl-v` block edit | `C-x r t` | rectangle insert (the `C-x r` family) |
| `>>` / `<<` | `TAB` / `C-M-\` (region) | mode-aware reindent |
| `gg=G` | `C-x h` then `C-M-\` | reindent the whole buffer |
| `o` / `O` | `C-e RET` / `C-a C-o` | open line below / above |
| `.` (repeat) | `C-x z` (`z z…` to keep going) | weaker than dot; macros fill the gap |
| `q{x}…@{x}` (macro) | `F3 … F4`, replay `F4` | keyboard macros |

### Search & replace

| Vim | Emacs | |
|---|---|---|
| `/foo` | `C-s foo` | incremental: matches as you type; `C-s`/`C-r` to cycle |
| `?foo` | `C-r foo` | backward |
| `n` / `N` | `C-s C-s` / `C-r C-r` | repeat in isearch |
| `*` (word under cursor) | `M-s .` | isearch the symbol at point |
| `:s/a/b/` (buffer) | `M-%` | `query-replace`; `C-M-%` for regexp |
| `:%s` project-wide | `C-x p r` | `project-query-replace-regexp` |
| live grep | `C-c f g` | `consult-ripgrep` (your config) |
| editable results | `M-s o` then `e` | `occur` then `occur-edit-mode`, like grug-far |

### Text objects (the gap)

Emacs has no `ciw` / `di(` / `dap`. Native idioms instead:

- Words: `M-d` / `M-DEL`. Sexps and blocks: `C-M-k` (kill), `C-M-SPC` (mark).
- Surround (`cs`, `ds`, `ys`) maps to `C-c s` (`embrace`), already configured.
- To select a function or block, add `expand-region` and grow the region with
  `C-=`. (Not installed yet.)

---

## Your dotfiles workflow, translated 1:1

The plugins you use map across directly. Same groups, `C-c` instead of `\`.

| Task | Neovim (`\` leader) | Emacs (`C-c`) |
|---|---|---|
| Find files | `\ff` | `C-c f f` |
| Live grep | `\fg` | `C-c f g` |
| Buffers | `\fb` | `C-c f b` (or `C-x b`) |
| Recent files | `\fo` | `C-c f o` |
| Commands palette | `\fa` | `C-c f a` (or `M-x`) |
| Notifications | `\fn` | `C-c f n` |
| File browser (oil) | `\c` | `C-c c` then dired; `C-x C-q` = wdired (edit like oil) |
| Go to definition | `\lgd` / `gd` | `C-c l d` (or `M-.`, back with `M-,`) |
| References | `\lf` | `C-c l f` |
| Hover docs (`K`) | `\lpd` | echo area auto; buffer via `C-c l h` |
| Rename | `\lr` | `C-c l r` |
| Code action | `\la` | `C-c l a` |
| Toggle inlay hints | `\lh` | `C-c l i` |
| Next / prev diagnostic | `]e` / `[e` | `C-c l n` / `C-c l p` |
| Buffer diagnostics list | `\lbd` | `C-c l e` |
| Run linter | `\ll` | `C-c l l` |
| Format buffer | `\i` | `C-c i` |
| Git status / porcelain | (gitsigns) | `C-c g g` for magit (or `C-x g`) |
| Stage / reset / preview hunk | `\gs` / `\gr` / `\gp` | `C-c g s` / `C-c g r` / `C-c g p` |
| Next / prev hunk | `]c` / `[c` | `C-c g n` / `C-c g N` |
| Blame line | `\gb` | `C-c g b` |
| Terminal toggle | `\t` | `C-c t` (eshell popup) |
| Surround | (nvim-surround) | `C-c s` |
| Search & replace (grug-far) | `\sr` | `C-x p r` or `M-s o` then `e` |
| Jump on screen (flash `s`) | `s` | `C-s` (isearch); `avy` if added |
| Org agenda | (orgmode) | `C-c a` |
| Completion accept | (blink) | `TAB` / `RET` (corfu popup) |
| Copilot accept / cycle | `<Tab>` / `<M-]>` | `TAB` / `M-]` `M-[` |

---

## What you gain

These run first-class here, where nvim reimplemented them:

- Org-mode. `nvim-orgmode` was emulating this. You get the agenda, capture, and
  literate-config engine, with your `~/Sync/orgfiles/` paths wired in.
- Magit (`C-c g g`). Staging, rebase, log, and stash all run interactively, well
  past gitsigns.
- dired + wdired (`C-c c`). oil.nvim copied this. Press `C-x C-q` to edit a
  directory as text, `C-c C-c` to apply.
- Built-ins, not plugins. eglot, flymake, treesit, which-key, and project ship
  with Emacs 30, so you track less than your `lazy-lock.json`.
- A live, self-documenting system. `C-h k` and `C-h f` explain anything; `C-x C-e`
  evaluates Elisp in place.
- Local-LLM completion still applies. Point completion at your `localhost:8000`
  server and it works in Emacs too.

---

## What's harder

- Modal muscle memory costs about two weeks of feeling slow, then passes. Skip
  evil-mode if you want the native paradigm to stick.
- No text objects. `ciw` and `di(` have no one-key equal; you use marks, `M-d`,
  sexp commands, and `embrace`.
- Dot-repeat (`.`) is weaker (`C-x z`). Reach for keyboard macros (`F3`/`F4`) on
  repetitive edits.
- Pinky load from `Control`. The Caps Lock remap fixes it.
- `Esc` does almost nothing. `C-g` cancels. This reflex takes the longest to
  rewire.

---

## A four-week plan

Add one layer per week.

- Week 0: `C-h t` tutorial, Caps-to-Ctrl remap. Open files, move around, let
  `C-g` become reflex.
- Week 1: movement, files, buffers, windows, undo (`C-/`), help keys. Edit notes,
  not your hot project.
- Week 2: `C-s` isearch, kill/yank (`C-k`/`C-y`/`M-y`), `M-%` replace, the `C-c`
  leader groups via which-key.
- Week 3: eglot (`C-c l …`), corfu completion, magit (`C-c g g`), dired/wdired
  (`C-c c`).
- Week 4: Org-mode, your language flows (julia-repl, `C-c i` format, flymake
  lint), reading `init.el`.
- Ongoing: each time you wonder how to do a Vim thing, look it up once. `C-h k`
  answers most of it.

---

## Living in the config

- Location: `~/.config/emacs/init.el`, one sectioned file (jump headers with
  `C-x ]` / `C-x [`). `early-init.el` runs first. Both symlink from this repo.
- Reload after an edit: evaluate a changed form with `C-x C-e` (cursor after the
  closing paren), or restart Emacs.
- Generated state lives in `~/.local/share/emacs` and `~/.cache/emacs`, outside
  the repo, so `git status` stays clean.
- Find a setting: grep with `C-c f g` inside `~/.config/emacs`, or `C-h v` on any
  variable.

---

## Pocket cheat sheet

```
CANCEL          C-g                 SAVE        C-x C-s
QUIT            C-x C-c             OPEN FILE   C-x C-f
UNDO            C-/                 SWITCH BUF  C-x b
HELP ON KEY     C-h k <key>         KILL BUF    C-x k
RUN COMMAND     M-x

MOVE   C-f C-b C-n C-p   word M-f M-b   line C-a C-e   buf M-< M->
EDIT   del C-d   killword M-d   killline C-k   yank C-y   cycle M-y
REGION C-SPC then move    copy M-w    cut C-w
SEARCH C-s (fwd)  C-r (back)   replace M-%   project C-x p r
WINDOW split C-x 2 / C-x 3   other C-x o   only C-x 1

LEADER (C-c):  f find · l lsp · g git · i format · t term · c dired · s surround
GIT:   C-c g g  magit          FORMAT: C-c i
FIND:  C-c f f / f g / f b      LSP:    C-c l d (def) / l r (rename) / l a (action)
```

When stuck: `C-g`, then `C-h k` on the key you meant to press.
