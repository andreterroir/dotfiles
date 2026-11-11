# Commit signing

On managed machines, `~/.gitconfig` sets `commit.gpgsign`, so every commit is
signed with SSH keys (`gpg.format = ssh`). All machines use their own
`~/.ssh/id_ed25519` by default, for both interactive and automated commits.
Desktop or dev-server profile, VM classification, and terminal presence do not
change that choice. This set-up provisions no hardware-backed identity, though
an override can still select a key it no longer manages.

Machine-key signatures identify the signing key, not a human presence check.
Anyone with access to the key can sign, including automation. Authentication
and key provisioning are separate policies described in the
[Provisioning model](provisioning.md).

## Configuration

`dot_gitconfig.tmpl` configures Git directly:

| Setting | Value | Purpose |
| --- | --- | --- |
| `user.signingKey` | absolute path to `~/.ssh/id_ed25519` | selects this machine's private key |
| `gpg.ssh.allowedSignersFile` | `~/.allowed_signers` | verifies signatures |

Transient environments omit these settings, leaving signing to an
environment-provided configuration such as Amp's `/etc/gitconfig`; see
[Transient profile](transient.md).

Git invokes `ssh-keygen -Y sign` with the private-key path. OpenSSH can use a
matching key in the active agent or read the private key directly. An absent
agent or a forwarded agent containing only unrelated keys does not prevent
signing with an unencrypted local key. Using the private-key path makes that
local signing capability explicit rather than relying on public-key lookup.

Existing `user.signingKey` overrides in a repository or
`~/.gitconfig.local` take precedence over the managed default; inspect them
with `git config --show-origin --get user.signingKey`.

## Unlocking and agents

Desktop machine keys can remain passphrase-protected. Unattended signing
requires an agent that can unlock or already holds that key; a fresh session
or an unrelated forwarded agent cannot unlock an encrypted local key by
itself. Do not remove desktop key passphrases for unattended signing; unlock
them in the platform agent. For dev-server and VM key requirements, see
[SSH identity bootstrap](provisioning.md#ssh-identity-bootstrap).

Existing agents remain configured for SSH authentication and encrypted desktop
keys.

### Fedora GNOME desktop

GNOME 46 moved SSH support out of `gnome-keyring-daemon` into gcr's
`gcr-ssh-agent`: a socket-activated systemd user socket at
`$XDG_RUNTIME_DIR/gcr/ssh`. It relays to an OpenSSH agent and, on a signature
request, runs `ssh-add` for the matching private key in `~/.ssh` itself, so
the machine key is usable without preloading.
`dot_bash_profile.tmpl` exports the socket if the session has not, then loads
`~/.ssh/id_ed25519` into it for Git signing and remote authentication. It adds
only a key that `ssh-keygen -y -P ''` reads without a passphrase: an encrypted
key is left to gcr, which loads it with the passphrase it stores when something
first signs with it, because a login-shell `ssh-add` would prompt every time.

### Dev servers

Nothing on a dev server runs an agent for the machine key: dev servers and VMs
sign with the key file directly, their machine keys have no passphrase, and a
forwarded agent, when present, serves SSH clients without holding the dev
server's local machine key.

## Verification

`run_once_after_allowed-signers.sh.tmpl` rewrites `~/.allowed_signers` from
GitHub's `ssh_signing_keys` under the principal `andre@terroir.systems`, so
every machine verifies every other machine's signature. A `work` machine
registers no key, so its signatures verify nowhere: the file lists GitHub's
keys, and an entry added by hand is lost at the next refresh. The script runs
once, so refresh it on demand on the other machines after a machine registers
a new signing key; a run without GitHub or `jq` fails and leaves the file it
has. See [One-shot set-up scripts](provisioning.md#one-shot-set-up-scripts).

```
git log --show-signature -1
git verify-commit HEAD
```

## Failures

| Message | Cause |
| --- | --- |
| Missing or unreadable machine private key | finish SSH identity provisioning, which runs again only on demand ([one-shot scripts](provisioning.md#one-shot-set-up-scripts)) |
| Passphrase prompt or failure in unattended signing | the encrypted machine key must be unlocked in the active agent |
| `No private key found for ...`, `Couldn't get agent socket?` | the override has neither a usable local private-key reference nor a matching key in the active agent |
| `fatal: failed to write commit object` | git aborts the commit when the signer fails |
