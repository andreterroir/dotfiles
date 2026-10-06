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

`dot_gitconfig.tmpl` wires git to two scripts in `~/.bin`:

| Setting | Value | Purpose |
| --- | --- | --- |
| `gpg.ssh.defaultKeyCommand` | `~/.bin/git-signing-key` | prints the public key git signs with |
| `gpg.ssh.program` | `~/.bin/git-ssh-keygen` | wraps `ssh-keygen` |
| `gpg.ssh.allowedSignersFile` | `~/.allowed_signers` | verifies signatures |

Git only accepts a bare key line when the type starts with `ssh-`, so the
selector prints `key::<public key>` for a FIDO2 key.

Git turns that into `ssh-keygen -Y sign -n git -f <public key> -U <buffer>`,
writing the public key to a temporary file when the selector printed `key::`.
`-U` asks `ssh-keygen` to sign with the matching key in `ssh-agent`.

## Key selection: `git-signing-key`

- `GIT_SIGNING_KEY=machine` prints the machine key and never consults an agent.
- Otherwise it lists the agent keys with `ssh-add -L` and keeps the first match
  among `approved_yubikeys`, the single source of which is
  `.chezmoitemplates/approved-yubikeys.bash` (one entry per YubiKey, named by
  its FIDO2 application, e.g. `ssh:5nfc`).
- With stdin on a terminal, a missing match is an error: an interactive commit
  must be signed by a YubiKey.
- Without a terminal, it falls back to the machine key.

## Signature: `git-ssh-keygen`

The wrapper replaces a `-f` argument whose key matches `~/.ssh/id_ed25519.pub`
with `~/.ssh/id_ed25519` and drops `-U`: the unattended signature is made
straight from the private key file, without an agent.

```
interactive:  git -> git-signing-key -> ssh-add -L -> ssh-keygen -U -f <sk pubkey>  -> agent -> YubiKey touch
unattended:   git -> git-signing-key -> ssh-keygen     -f ~/.ssh/id_ed25519         -> private key file
```

A resident key does not match the machine key, so its arguments pass through
unchanged and `-U` remains: the agent performs the FIDO2 signature. Each
signature needs one YubiKey touch; the resident keys carry user presence only,
not user verification, so signing never asks for the FIDO PIN.

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

## macOS

Apple's OpenSSH has no FIDO provider (`ssh-keygen -t ed25519-sk` fails with
"No FIDO SecurityKeyProvider specified", and `ssh-keygen -K` with "Cannot
download keys without provider"), so the `openssh` formula provides the
binaries and `run_after_10-ssh-identity.sh.tmpl` prepends
`/opt/homebrew/opt/openssh/bin` to `PATH`.

The system agent (`com.openssh.ssh-agent`, the default `SSH_AUTH_SOCK`) loads a
resident key but refuses FIDO signatures with "agent refused operation", so
signing uses Homebrew's agent instead. `Library/LaunchAgents/systems.terroir.homebrew-ssh-agent.plist`
runs `~/.bin/homebrew-ssh-agent`, bootstrapped by
`run_after_11-homebrew-ssh-agent.sh.tmpl`; it serves
`~/.ssh/homebrew-agent.sock` and loads the resident and machine keys.
`dot_bash_profile.tmpl` and `dot_bashrc` export `SSH_AUTH_SOCK` at that socket.
`UseKeychain` and `AddKeysToAgent` in `private_dot_ssh/private_config.tmpl`
concern `ssh`, not this signing path.

## Failures

| Message | Cause |
| --- | --- |
| `git-signing-key: no authorized resident YubiKey key in the agent` | interactive commit, no approved resident key in the agent |
| `git-signing-key: no SSH signing key available` | no machine key and no resident key |
| `Couldn't get agent socket?` | `-U` with no agent at `SSH_AUTH_SOCK` |
| `agent refused operation` | the agent cannot perform the FIDO2 signature, e.g. the loaded key is not the resident key or the socket points at a dead agent |
| `fatal: failed to write commit object` | git aborts the commit when the signer fails |
