# Provisioning model

The repository is public and its history has been cleaned. Chezmoi manages
the current configuration; local machine-specific files remain untracked.

## Identities and Git

YubiKeys represent interactive human actions. Machine-local
`~/.ssh/id_ed25519` keys represent unattended automation.

The independent `vm` class also permits machine keys for interactive signing.
VMs retain desktop/server tooling but do not provision Passage, its store,
identities, or password-update hook. Existing stores
and local identities are not deleted: this policy does not revoke access
previously granted outside chezmoi. A YubiKey is optional, through an
explicitly installed resident key or agent forwarding. VM setup never tries
to download one. The VM's passphrase-free machine key is registered for
GitHub authentication and signing, not for access to the password server.

VM policy takes precedence over the other columns; desktop/server still
determines which tools and SSH agent are installed.

| Aspect | macOS desktop | Fedora desktop | Headless server | VM (desktop or headless) |
| --- | --- | --- | --- | --- |
| Git commit signing | Interactive commits require an approved resident `ed25519-sk` key; unattended commits use the machine key. | Interactive commits require an approved resident key; unattended commits use the machine key. | Interactive commits require an approved forwarded resident key; unattended commits use the machine key. | Interactive commits prefer an approved resident key, falling back to the machine key; unattended commits use the machine key. |
| Passwords | Passage uses the travelling 5 NFC identity for `git@git.terroir.systems:passwords.git`. Slate's untracked local age identity decrypts only `work/*`. | Passage uses the travelling 5 NFC identity.\* | Passage is not provisioned. | Passage is not provisioned. |
| Remote server access | Use a resident key and forward its agent. | Use a resident key and forward its agent.\* | Use a forwarded resident key for onward access; no machine-key access is provisioned by default. | Use an explicitly installed or forwarded resident key; no machine-key fallback is configured for managed remote servers. |
| GitHub access | `gh` OAuth and HTTPS provide unattended access; a resident key provides SSH access. | `gh` OAuth and HTTPS provide unattended access; a resident key provides SSH access.\* | `gh` OAuth and HTTPS provide unattended access; a forwarded resident key provides SSH access. | `gh` OAuth and HTTPS are available; SSH accepts an approved resident key or the VM machine key. |

\* On x1, Passage uses the attached 5C Nano instead of the travelling 5 NFC.
Its machine key is also an authentication fallback for the managed SSH
destinations, including Passage synchronization and GitHub SSH access.
Interactive signing still requires an approved resident key.

`passage` is the shared provisioning flag: init derives it as
`desktop && !vm`, with no independent override. It controls Passage
installation, identities, store checkout, synchronization, and its age
YubiKey plugin, but not general SSH/FIDO support. Both non-VM servers and
VMs therefore omit Passage without sharing signing or authentication policy.

Every signing key goes through an agent: git runs `ssh-keygen -Y sign`, which
resolves the key `gpg.ssh.defaultKeyCommand` printed through `SSH_AUTH_SOCK`.
The macOS Homebrew agent, GNOME's gcr-ssh-agent, and a systemd user ssh-agent
on servers each make the machine key reachable. A trusted tool that allocates a
PTY must set `GIT_SIGNING_KEY=machine`.

Managed SSH configuration applies only to `github.com`,
`git.terroir.systems`, and `chalon`. Both resident keys are authentication and
signing keys. Only x1's machine key is a general backup authentication key;
VM machine keys are authentication fallbacks for GitHub only.
Chezmoi manages neither `git.terroir.systems` nor `chalon`; both are SSH
destinations only. `AGENTS.md` names every hostname with its OS and role.
Other hosts, aliases, and forwarding rules belong in untracked
`~/.ssh/local_config`.

## Operations

Run `chezmoi init` before apply/update when adopting this policy or after
changing `vm`. Init recomputes `passage` rather than preserving its previous
value, and removes an obsolete password-update hook when Passage is disabled.
Apply rejects a missing or contradictory flag and directs you to init.
Disabling Passage removes managed plugin references and the update helper,
not existing store contents or machine-local identities.

`run_after_10-ssh-identity.sh.tmpl` creates missing machine keys and registers
public keys with GitHub. It tolerates GitHub API outages when its local keys
already exist, but fails after creating a key because registration is then
required. The approved resident-key list has one source in
`.chezmoidata.toml`, used by the Bash selectors and VM public-only SSH
identities. The public-only files allow forwarded keys to match SSH's
identity filter without installing resident private-key references.

`run_after_30-amp-runner.sh.tmpl` enables the systemd user unit
`~/.config/systemd/user/amp-runner.service` on every Linux machine. It runs
`amp --no-tui` from `~/code`, names the runner after the machine's hostname,
serves `~/code/dotfiles` explicitly, and discovers the other checkouts beneath
`~/code`, so threads can be created on the machine from ampcode.com. Linger
keeps the runner up without a login, as it does for the servers' ssh-agent.
