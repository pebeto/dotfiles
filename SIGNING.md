# GitHub keys (per-device: one key does auth + signing)

Each machine has its own ed25519 key that handles BOTH jobs: authentication
(clone/push over `git@github.com`) and commit signing. Nothing about keys is shared or
synced: lose a machine, revoke its one key on GitHub. This replaced a GPG-key-synced-
over-Syncthing setup that fought Syncthing and per-OS config at every turn.

## What lives where

- **Signing behaviour** -> this repo, `.gitconfig` (symlinked to `~/.gitconfig`):
  `gpg.format = ssh`, `commit.gpgsign = true`. No key here; the key is per-machine.
- **Per-machine bits** -> `~/.gitconfig.local` (untracked), written by
  `github-key-setup.sh`: `user.signingkey` and `gpg.ssh.allowedSignersFile`, plus the
  home for `safe.directory`. Pulled in by an `[include]` at the end of `.gitconfig`.
- **The key** -> `~/.ssh/id_ed25519`, generated on the machine, never copied anywhere.
  `~/.ssh/config` points `github.com` at it with `IdentitiesOnly yes`. Not in the repo,
  not in Syncthing.

## Set up a machine

```
cd ~/git/dotfiles && git pull
./install.sh            # macOS: ./install-macos.sh   (symlinks .gitconfig)
./github-key-setup.sh
```

The script makes `~/.ssh/id_ed25519`, wires ssh + git to use it, and prints the public
key. Register that ONE key on GitHub TWICE (Settings -> SSH and GPG keys -> New SSH key):

- **Authentication Key** — clone/push over `git@github.com`.
- **Signing Key** — the Verified badge on your commits.

Verify:
- `ssh -T git@github.com` -> "Hi pebeto!" confirms auth.
- `git commit --allow-empty -m test && git log --show-signature -1` shows a good
  signature; pushed commits show **Verified**.

The key is passphrase-less, so push and sign are both prompt-free. It grants push, so
add a passphrase if you want that protection (ssh-agent caches it after first unlock):
`ssh-keygen -p -f ~/.ssh/id_ed25519`.

Skipping `github-key-setup.sh` breaks commits: `.gitconfig` sets `commit.gpgsign = true`
with no key until the script writes `~/.gitconfig.local`.

## Bootstrapping when auth is already broken

If you've removed the old auth key from GitHub, SSH is dead until a new key is
registered — but this repo is public, so pull the script over HTTPS to break the cycle:

```
cd ~/git/dotfiles
git pull https://github.com/pebeto/dotfiles.git main
./install.sh            # or ./install-macos.sh
./github-key-setup.sh   # generates + wires the key, prints it
# register the printed key on GitHub as Authentication + Signing, then:
ssh -T git@github.com
```

## Notes

- **Nothing syncs.** `~/.ssh` and `~/.gnupg` must NOT be Syncthing folders. Unshare them
  if they still are from the old setup.
- **Old keys.** The shared `id_rsa` and the GPG signing key are no longer used by GitHub.
  `id_rsa` still serves other hosts (tilde.club), so it stays in `~/.ssh`; just remove it
  from GitHub. Keep the GPG key for `pass`.
- **Unverified on GitHub?** Committer email must match `user.email` and a verified email
  on your account, and the machine's key must be registered as a Signing key.
- **Local cross-machine verify (optional).** `~/.config/git/allowed_signers` lists only
  the local machine's key. Add the others' public keys there if you want
  `--show-signature` to resolve commits made on another machine.
