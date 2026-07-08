# Commit signing & key sync

Verified ("Validated") commits on GitHub, kept working across the T470 and the
workstation without copying keys by hand.

## What lives where

- **Signing config** -> this repo, `.gitconfig` (symlinked to `~/.gitconfig` by
  `install.sh`). Sets `user.signingkey`, `commit.gpgsign`, the gh credential
  helper, and LFS. Not secret: the key fingerprint and email are already public
  in every signed commit.
- **Per-machine git bits** -> `~/.gitconfig.local` (untracked, created by hand).
  An `[include]` at the end of `.gitconfig` pulls it in. Put `safe.directory`
  entries, a work email, or a machine-specific `signingkey` here.
- **Private keys** (GPG secret key, `~/.ssh/id_*`) -> NEVER in this repo, it is
  public. Synced peer-to-peer with Syncthing, same channel as the org files.

## Key sync via Syncthing

Add `~/.ssh` and `~/.gnupg` as their OWN Syncthing folders (Add Folder -> point at
the directory), and share each only with the machines that sign commits:

- t470, workstation, MacBook Pro   (NOT the iPhone)

Each folder has a `.stignore` that skips agent sockets, lock files, `random_seed`,
keybox backups, and `.DS_Store`; only key material, trust, and `config` sync. Safe
because the machines are used one at a time (no simultaneous edits).

DO NOT nest keys inside a broadly-shared folder. `~/Sync` (org files, books, the
KeePass db) replicates to the iPhone too, so dropping keys there sprays your private
SSH/GPG keys onto every device that folder touches. Keep the key folders separate and
scoped to the machines above.

On a machine that already has its own `~/.ssh`/`~/.gnupg` (e.g. the work Mac), back it
up first, then let Syncthing reconcile, so nothing gets clobbered by a same-named file.

## New-machine checklist

1. `git clone git@github.com:pebeto/dotfiles.git ~/git/dotfiles && cd ~/git/dotfiles`
2. `./install.sh` (Linux) or `./install-macos.sh` (Mac) — symlinks `.gitconfig`.
3. Create `~/.gitconfig.local` for anything machine-specific, or leave it out.
4. Join the machine to Syncthing and accept the `~/.ssh` and `~/.gnupg` folders;
   wait for them to finish syncing.
5. `gpg --list-secret-keys` — confirm the signing key is present.
6. Test: `git commit --allow-empty -m 'signing test' && git log --show-signature -1`
   shows a good signature; on GitHub the commit shows **Verified**.

If GitHub shows **Unverified**: the committer email must match `user.email`, the
GPG key's UID email, and a verified email on your GitHub account, and the key's
public half must be uploaded at github.com/settings/keys.
