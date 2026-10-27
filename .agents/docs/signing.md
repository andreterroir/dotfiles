# Commit signing

`~/.gitconfig` sets `commit.gpgsign`, so every commit is signed with SSH keys
(`gpg.format = ssh`). All machines use their own `~/.ssh/id_ed25519` by
default, for both interactive and automated commits. Desktop/server role,
VM classification, terminal presence, and connected YubiKeys do not change
that choice. A repository can explicitly opt into hardware-backed signing.

Machine-key signatures identify the signing key, not a human presence check.
Anyone with access to the key can sign; human and automated commits are no
longer distinguished by signing key. YubiKeys remain required for managed
remote-server access and Passage, subject to the existing x1 authentication
and Slate work-only Passage exceptions. GitHub still supports YubiKey SSH
authentication, including during bootstrap; HTTPS/OAuth remains available.

## Configuration

`dot_gitconfig.tmpl` configures Git directly, without a signing selector:

| Setting | Value | Purpose |
| --- | --- | --- |
| `user.signingKey` | absolute path to `~/.ssh/id_ed25519` | selects this machine's private key |
| `gpg.ssh.allowedSignersFile` | `~/.allowed_signers` | verifies signatures |

Git invokes `ssh-keygen -Y sign` with the private-key path. OpenSSH can use a
matching key in the active agent or read the private key directly. An absent
agent or a forwarded agent containing only unrelated keys does not prevent
signing with an unencrypted local key. Using the private-key path makes that
local signing capability explicit rather than relying on public-key lookup.

```
default:   git -> ssh-keygen -f <machine private key> -> agent or local key
opt-in:    git -> ssh-keygen -f <YubiKey public key>  -> agent -> YubiKey touch
```

The old `git-signing-key` helper is removed on apply. `GIT_SIGNING_KEY` is no
longer used. Existing `user.signingKey` overrides in a repository or
`~/.gitconfig.local` take precedence over the managed default; inspect them
with `git config --show-origin --get user.signingKey`.

## Opt into YubiKey signing

On a desktop with its resident key downloaded, run inside the repository:

```sh
git config --local user.signingKey "$HOME/.ssh/id_ed25519_sk.pub"
```

OpenSSH can use the matching resident key in the active agent or its local
private-key reference; both require the YubiKey. For forwarded keys on a VM,
use one of the managed public-only files `~/.ssh/identities/yubikey-{1,2}`
instead. On another host, provide a public-key file for the intended
forwarded identity. Public-only identities need a matching key in the agent.
The signer must support FIDO and reach the YubiKey; current resident keys
require touch.
If the key is unavailable or signing is refused, the commit fails rather
than falling back to the machine key. Merely listing the key with
`ssh-add -L` does not prove the hardware is present.

Restore the machine default with:

```sh
git config --local --unset user.signingKey
```

Existing YubiKey signing registrations are retained for opt-in signing and
verification of older commits. No authentication registration changes are
needed for this policy.

## Unlocking and agents

Desktop machine keys can remain passphrase-protected. Unattended signing
requires an agent that can unlock or already holds that key; a fresh session
or an unrelated forwarded agent cannot unlock an encrypted local key by
itself. Do not remove desktop key passphrases as part of adopting this policy.
Server and VM keys already have no passphrase and can sign directly without
an agent, including from cron. Provisioning rejects encrypted server/VM keys
with manual migration instructions, without replacing the key.

Existing agents remain configured for SSH authentication, encrypted desktop
keys, and optional YubiKey signing.

### macOS

Apple's OpenSSH has no FIDO provider (`ssh-keygen -t ed25519-sk` fails with
"No FIDO SecurityKeyProvider specified", and `ssh-keygen -K` with "Cannot
download keys without provider"), so the `openssh` formula provides the
binaries and `run_after_10-ssh-identity.sh.tmpl` prepends
`/opt/homebrew/opt/openssh/bin` to `PATH`.

The system agent (`com.openssh.ssh-agent`, the default `SSH_AUTH_SOCK`) loads a
resident key but refuses FIDO signatures with "agent refused operation", so
YubiKey operations use Homebrew's agent.
`Library/LaunchAgents/systems.terroir.homebrew-ssh-agent.plist` runs
`~/.bin/homebrew-ssh-agent`, bootstrapped by
`run_onchange_after_11-homebrew-ssh-agent.sh.tmpl`; it serves
`~/.ssh/homebrew-agent.sock` and loads the resident and machine keys.
The desktop machine key is normally passphrase-protected, and only the
system `ssh-add` can unlock it from the Keychain, so the wrapper loads it with
`/usr/bin/ssh-add --apple-use-keychain`; Homebrew's `ssh-add` has no Keychain
support.
`dot_bash_profile.tmpl` and `dot_bashrc` export `SSH_AUTH_SOCK` at that socket.
`UseKeychain` and `AddKeysToAgent` in `private_dot_ssh/private_config.tmpl`
concern `ssh`, not this signing path.

### Fedora GNOME desktop

GNOME 46 moved SSH support out of `gnome-keyring-daemon` into gcr's
`gcr-ssh-agent`: a socket-activated systemd user socket at
`$XDG_RUNTIME_DIR/gcr/ssh`. It relays to an OpenSSH agent and, on a signature
request, runs `ssh-add` for the matching private key in `~/.ssh` itself, so
both the machine key and the resident key file are used without preloading.
`dot_bash_profile.tmpl` only exports the socket if the session has not:
preloading with its own `ssh-add` would prompt for the machine key's passphrase
in every login shell, because `ssh-add` decrypts the key file itself instead of
asking gcr for the passphrase it has stored.

The agent runs without a terminal, so OpenSSH would render its "Confirm user
presence" notice for a touch through `$SSH_ASKPASS` — Fedora's
`/usr/libexec/openssh/gnome-ssh-askpass`, whose window grabs the keyboard and
makes GNOME ask to allow shortcut inhibition on every signature.
`gcr-ssh-agent.service.d/no-ssh-askpass.conf` empties `SSH_ASKPASS` for the
agent, leaving the YubiKey's blink as the prompt; a touch-only resident key
never needs the PIN that the agent would otherwise have to ask for.

### Headless servers

`run_after_12-ssh-agent.sh.tmpl` enables a systemd user service
(`~/.config/systemd/user/ssh-agent.service`) that runs
`ssh-agent -a $XDG_RUNTIME_DIR/ssh-agent.sock`, loads the machine key, and sets
`SSH_AUTH_SOCK` in the user manager environment. It also enables linger, so the
agent runs from boot rather than from a login. `dot_bash_profile.tmpl` exports
the socket to login shells, keeping a forwarded agent if one is present.

This agent remains available for SSH clients, but default commit signing no
longer requires it. A forwarded agent can still support explicit YubiKey
signing without holding the server's local machine key.

## Registration and verification

`run_after_10-ssh-identity.sh.tmpl` creates the machine key if it is missing,
downloads the resident key with `ssh-keygen -K` (touch and PIN) on a desktop if
it is missing, and registers both on GitHub for `andreterroir`: the machine key
as a signing key, the resident key as an authentication and signing key, and
x1's machine key additionally as an authentication key.
On VMs the machine key is also a GitHub authentication key, and resident
keys are registered only if explicitly installed beforehand.

`run_after_allowed-signers.sh.tmpl` rewrites `~/.allowed_signers` from GitHub's
`ssh_signing_keys` under the principal `andre@terroir.systems`, so every machine
verifies every other machine's signature. A machine that is offline keeps the
file it has.

```
git log --show-signature -1
git verify-commit HEAD
```

## Failures

| Message | Cause |
| --- | --- |
| Missing or unreadable machine private key | finish SSH identity provisioning; a connected YubiKey does not replace the default key |
| Passphrase prompt or failure in unattended signing | the encrypted machine key must be unlocked in the active agent |
| `No private key found for ...`, `Couldn't get agent socket?` | the override has neither a usable local private-key reference nor a matching key in the active agent |
| `agent refused operation` | the agent cannot perform the FIDO2 signature, e.g. the loaded key is not the resident key or the socket points at a dead agent |
| `fatal: failed to write commit object` | git aborts the commit when the signer fails |
