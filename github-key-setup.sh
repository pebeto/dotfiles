#!/usr/bin/env bash
# github-key-setup.sh -- per-device GitHub key. Run ONCE on each machine.
#
# ONE ed25519 key per machine that does BOTH jobs: authentication (clone/push) and
# commit signing. It generates ~/.ssh/id_ed25519, points ssh at it for github.com,
# sets it as git's signing key, and prints the public half. Register that ONE key on
# GitHub TWICE: once as an Authentication key, once as a Signing key.
#
# Nothing about keys is shared or synced: each machine has its own, and losing one
# means revoking one key on GitHub. ~/.ssh and ~/.gnupg must NOT be Syncthing folders.
set -euo pipefail

KEY="$HOME/.ssh/id_ed25519"
CONF="$HOME/.ssh/config"
ALLOWED="$HOME/.config/git/allowed_signers"
EMAIL="$(git config --global user.email)"
HOST="$(hostname -s 2>/dev/null || uname -n | cut -d. -f1)"

mkdir -p "$HOME/.ssh" "$HOME/.config/git"
chmod 700 "$HOME/.ssh"

# 1. One ed25519 key for this machine (auth + signing). Passphrase-less keeps commits
#    and pushes prompt-free. It also grants push, so add a passphrase if you want that
#    protection (ssh-agent then caches it): ssh-keygen -p -f "$KEY"
if [ ! -f "$KEY" ]; then
	ssh-keygen -t ed25519 -C "$(whoami)@${HOST}" -f "$KEY" -N ""
	echo "generated $KEY"
else
	echo "$KEY already exists, reusing it"
fi
chmod 600 "$KEY"; chmod 644 "$KEY.pub"

# 2. Use this key for GitHub auth. IdentitiesOnly stops ssh from also offering other
#    keys (e.g. id_rsa) and tripping "Too many authentication failures".
if ! grep -qiE '^[[:space:]]*Host[[:space:]].*\bgithub\.com\b' "$CONF" 2>/dev/null; then
	printf '\nHost github.com\n    IdentityFile %s\n    IdentitiesOnly yes\n' "$KEY" >> "$CONF"
	echo "added github.com block to $CONF"
else
	echo "github.com already in $CONF -- make sure it uses $KEY"
fi

# 3. Same key signs commits (per-machine, so it lives in ~/.gitconfig.local).
git config --file "$HOME/.gitconfig.local" user.signingkey "$KEY.pub"
git config --file "$HOME/.gitconfig.local" gpg.ssh.allowedSignersFile "$ALLOWED"

# 4. Trust it for local signature verification.
touch "$ALLOWED"
if ! grep -qF "$(awk '{print $2}' "$KEY.pub")" "$ALLOWED" 2>/dev/null; then
	printf '%s namespaces="git" %s\n' "$EMAIL" "$(cat "$KEY.pub")" >> "$ALLOWED"
fi

# 5. Register on GitHub.
cat <<EOF

=== Register this ONE key on GitHub TWICE (Settings -> SSH and GPG keys) ===
    New SSH key  ->  Key type: Authentication Key   (restores clone/push)
    New SSH key  ->  Key type: Signing Key          (verifies your commits)
    Title: ${HOST}
    Key:
$(cat "$KEY.pub")

Verify auth:  ssh -T git@github.com          (expect "Hi pebeto! ...")
Verify sign:  git commit --allow-empty -m test && git log --show-signature -1
EOF
