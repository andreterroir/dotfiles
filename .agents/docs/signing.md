# Commit signing

`~/.gitconfig` sets `commit.gpgsign`, so every commit is signed with SSH keys
(`gpg.format = ssh`). YubiKeys represent the human at the keyboard; machine
keys represent automation:

| Session | Signing key |
| --- | --- |
| Interactive (stdin is a terminal) | an approved resident `ed25519-sk` key on the YubiKey |
| Unattended (no terminal) | this machine's `~/.ssh/id_ed25519` |
| `GIT_SIGNING_KEY=machine` | the machine key, for a trusted tool that allocates a PTY |

## Configuration

`dot_gitconfig.tmpl` wires git to one selector in `~/.bin`:

| Setting | Value | Purpose |
| --- | --- | --- |
| `gpg.ssh.defaultKeyCommand` | `~/.bin/git-signing-key` | prints the public key git signs with |
| `gpg.ssh.allowedSignersFile` | `~/.allowed_signers` | verifies signatures |

Git runs the command itself and validates its output as a literal public key,
not a path. `git-signing-key` prints the machine key bare, because an
`ssh-ed25519` line is a literal key to every git with SSH signing (2.34+), and
the resident key as `key::<sk-ssh-ed25519>`, because git only accepts a bare
key when its type starts with `ssh-` (git 2.35+).

Git writes that literal key to a temporary file and runs
`ssh-keygen -Y sign -n git -f <file>`. Since git 2.40 it also passes `-U`;
without it `ssh-keygen` still resolves the key through the agent when the agent
holds it. Either way the private key never leaves the agent, so every signing
key must be loaded into an agent that `SSH_AUTH_SOCK` reaches.

## Key selection: `git-signing-key`

- `GIT_SIGNING_KEY=machine` prints the machine key and never consults an agent.
- Otherwise it lists the agent keys with `ssh-add -L` and keeps the first match
  among `approved_yubikeys`, the single source of which is
  `.chezmoitemplates/approved-yubikeys.bash` (one entry per YubiKey, named by
  its FIDO2 application, e.g. `ssh:5nfc`).
- With stdin on a terminal, a missing match is an error: an interactive commit
  must be signed by a YubiKey.
- Without a terminal, it falls back to the machine key.

A resident key carries user presence only, not user verification, so signing
never asks for the FIDO PIN, just a touch.

```
interactive:  git -> git-signing-key -> ssh-add -L -> ssh-keygen -U -f <sk pubkey>       -> agent -> YubiKey touch
unattended:   git -> git-signing-key              -> ssh-keygen     -f <machine pubkey>  -> agent -> machine key
```

## The agent per platform

### macOS

Apple's OpenSSH has no FIDO provider (`ssh-keygen -t ed25519-sk` fails with
"No FIDO SecurityKeyProvider specified", and `ssh-keygen -K` with "Cannot
download keys without provider"), so the `openssh` formula provides the
binaries and `run_after_10-ssh-identity.sh.tmpl` prepends
`/opt/homebrew/opt/openssh/bin` to `PATH`.

The system agent (`com.openssh.ssh-agent`, the default `SSH_AUTH_SOCK`) loads a
resident key but refuses FIDO signatures with "agent refused operation", so
signing uses Homebrew's agent instead. `Library/LaunchAgents/systems.terroir.homebrew-ssh-agent.plist`
runs `~/.bin/homebrew-ssh-agent`, bootstrapped by
`run_onchange_after_11-homebrew-ssh-agent.sh.tmpl`; it serves
`~/.ssh/homebrew-agent.sock` and loads the resident and machine keys.
The machine key is passphrase-protected, and only the system `ssh-add` can
unlock it from the Keychain, so the wrapper loads it with
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

A process signs only if `SSH_AUTH_SOCK` points at an agent holding its key.
Login shells get it from `dot_bash_profile.tmpl` and systemd user units from
the user manager environment, but a bare cron job inherits neither and cannot
sign. Give such a job `SSH_AUTH_SOCK` explicitly.

## Registration and verification

`run_after_10-ssh-identity.sh.tmpl` creates the machine key if it is missing,
downloads the resident key with `ssh-keygen -K` (touch and PIN) on a desktop if
it is missing, and registers both on GitHub for `andreterroir`: the machine key
as a signing key, the resident key as an authentication and signing key, and
x1's machine key additionally as an authentication key.

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
| `git-signing-key: no authorized resident YubiKey key in the agent` | interactive commit, no approved resident key in the agent |
| `git-signing-key: no SSH signing key available` | no machine key and no resident key |
| `No private key found for ...`, `Couldn't get agent socket?` | the key is not loaded in the agent `SSH_AUTH_SOCK` points at |
| `agent refused operation` | the agent cannot perform the FIDO2 signature, e.g. the loaded key is not the resident key or the socket points at a dead agent |
| `fatal: failed to write commit object` | git aborts the commit when the signer fails |
