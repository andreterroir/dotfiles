# Provisioning model

The repository is public and its history has been cleaned. Chezmoi manages
the current configuration; local machine-specific files remain untracked.

## Identities and Git

YubiKeys represent interactive human actions. Machine-local
`~/.ssh/id_ed25519` keys represent unattended automation.

| Aspect | Desktop | x1 exception | Headless server |
| --- | --- | --- | --- |
| Git commit signing | Interactive commits require an approved resident `ed25519-sk` key; unattended commits use the machine key. | The same signing policy applies. | A forwarded resident key signs interactive commits; unattended commits use the machine key. |
| Passwords | Passage uses the 5 NFC YubiKey identity for `git@git.terroir.systems:passwords.git`. Slate's untracked identity may decrypt only `work/*`. | Passage uses the 5C Nano attached to x1; the machine key can synchronize Passage after login when no YubiKey is loaded. | Passage is not provisioned. |
| Remote server access | Use a resident key and forward its agent. | The machine key is the only general backup authentication key. | Use the forwarded resident key for onward access; no machine-key access is provisioned by default. |
| GitHub access | `gh` OAuth and HTTPS provide unattended access; a resident key is used for interactive SSH. | The machine key is also a GitHub SSH authentication fallback. | `gh` OAuth and HTTPS provide unattended access; a forwarded resident key is used for interactive SSH. |

Every signing key goes through an agent: git runs `ssh-keygen -Y sign`, which
resolves the key `gpg.ssh.defaultKeyCommand` printed through `SSH_AUTH_SOCK`.
The macOS Homebrew agent, GNOME's gcr-ssh-agent, and a systemd user ssh-agent
on servers each make the machine key reachable. A trusted tool that allocates a
PTY must set `GIT_SIGNING_KEY=machine`.

Managed SSH configuration applies only to `github.com` and
`git.terroir.systems`. Both resident keys are authentication and signing keys.
Only x1's machine key is a general backup authentication key. Other hosts,
aliases, and forwarding rules belong in untracked `~/.ssh/local_config`.

## Operations

`run_after_10-ssh-identity.sh.tmpl` creates missing machine keys and registers
public keys with GitHub. It tolerates GitHub API outages when its local keys
already exist, but fails after creating a key because registration is then
required. The approved resident-key list has one source in
`.chezmoitemplates/approved-yubikeys.bash`.
