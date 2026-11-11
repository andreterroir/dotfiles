# Commit signing

On managed machines, `~/.gitconfig` sets `commit.gpgsign`, so every commit is
signed with SSH keys (`gpg.format = ssh`). All machines sign with their own
`~/.ssh/id_ed25519`, interactive and automated commits alike. This set-up
provisions no hardware-backed identity, though an override can still select a
key it no longer manages.

A machine-key signature identifies the signing key, not a human presence
check: anyone with the key can sign, including automation. Authentication and
key provisioning are separate policies, described in the
[Provisioning model](provisioning.md).

## Configuration

`dot_gitconfig.tmpl` configures Git directly:

| Setting | Value | Purpose |
| --- | --- | --- |
| `user.signingKey` | absolute path to `~/.ssh/id_ed25519` | selects this machine's private key |
| `gpg.ssh.allowedSignersFile` | `~/.allowed_signers` | verifies signatures |

Transient environments omit these settings, leaving signing to an
environment-provided configuration such as Amp's `/etc/gitconfig`; see
[Portable set-up](provisioning.md#portable-set-up).

Git invokes `ssh-keygen -Y sign` with the private-key path, so OpenSSH reads
the key directly or uses a matching key in the active agent. An absent agent,
or one holding only unrelated keys, does not prevent signing with an
unencrypted local key. Existing `user.signingKey` overrides in a repository or
`~/.gitconfig.local` take precedence over the managed default; inspect them
with `git config --show-origin --get user.signingKey`.

## Unlocking and agents

Desktop machine keys can remain passphrase-protected, so unattended signing
needs an agent that holds or unlocks the key. Do not remove the passphrase to
get one.

### Fedora GNOME desktop

GNOME 46 moved SSH support into gcr's `gcr-ssh-agent`: a socket-activated
systemd user socket at `$XDG_RUNTIME_DIR/gcr/ssh`. It relays to an OpenSSH
agent and, on a signature request, runs `ssh-add` for the matching key itself.
`dot_bash_profile.tmpl` exports the socket if the session has not, then adds
`~/.ssh/id_ed25519` when `ssh-keygen -y -P ''` reads it without a passphrase.
An encrypted key is left to gcr, which stores its passphrase at the first
signature, because a login-shell `ssh-add` would prompt every time.

### Dev servers

Nothing runs an agent for the machine key: dev servers and VMs sign with the
key file directly, and their keys have no passphrase. A forwarded agent, when
present, serves SSH clients without holding that key.

## Verification

`run_once_after_allowed-signers.sh.tmpl` rewrites `~/.allowed_signers` from
GitHub's `ssh_signing_keys` under the principal `andre@terroir.systems`, so
every machine verifies every other machine's signature. A `work` machine
registers no key, so its signatures verify nowhere, and an entry added by hand
is lost at the next refresh. The script runs once, so refresh the file on the
other machines after a machine registers a new signing key; see
[One-shot set-up scripts](provisioning.md#one-shot-set-up-scripts).

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
