# Provisioning model

Chezmoi manages the shared configuration; machine-local overrides remain
untracked. See [AGENTS.md](../../AGENTS.md#machines) for the machine inventory
and [Commit signing](signing.md) for signing configuration and agent setup.

## Roles and Passage

Init derives `desktop` without prompting: true on macOS and on Linux with
`gnome-shell` on PATH. `server` is its inverse; `linux.desktop` identifies
Linux desktops. Role selects tools and the SSH agent, not a hostname.

`vm` is independent of role. Linux init detects it with
`systemd-detect-virt --vm` unless already configured, preserving the value on
subsequent init runs. On other platforms it defaults to false and can be
set in the chezmoi config. VMs retain desktop/server tooling.

Init derives `passage` as `desktop && !vm`, with no independent override.
It controls Passage installation, identities, store checkout,
synchronization, and the age YubiKey plugin, not general SSH/FIDO support.
Neither headless servers nor VMs provision Passage.

Run `chezmoi init` before apply/update when adopting this policy or after
changing `vm`. Init recomputes `passage` and regenerates the password-update
hook, omitting it when Passage is disabled. Apply rejects missing or
contradictory policy data. Disabling Passage removes managed plugin
references and the update helper, never existing stores or machine-local
identities. This is a provisioning policy, not revocation of manually
granted access.

## Authentication and sudo

VM policy takes precedence over the other columns.

| Aspect | macOS desktop | Fedora desktop | Headless server | VM (desktop or headless) |
| --- | --- | --- | --- | --- |
| Passwords | Passage uses the travelling 5 NFC identity for `git@git.terroir.systems:passwords.git`. Slate's untracked local age identity decrypts only `work/*`. | Passage uses the travelling 5 NFC identity.\* | Passage is not provisioned. | Passage is not provisioned. |
| Remote server access | Use a resident key and forward its agent. | Use a resident key and forward its agent.\* | Use a forwarded resident key for onward access; no machine-key access is provisioned by default. | Use an explicitly installed or forwarded resident key; no machine-key fallback is configured for managed remote servers. |
| GitHub access | `gh` OAuth and HTTPS provide unattended access; a resident key provides SSH access. | `gh` OAuth and HTTPS provide unattended access; a resident key provides SSH access.\* | `gh` OAuth and HTTPS provide unattended access; a forwarded resident key provides SSH access. | `gh` OAuth and HTTPS are available; SSH accepts an approved resident key or the VM machine key. |
| Sudo | Existing system policy; no passwordless grant. | Existing system policy; no passwordless grant. | Must require a password to prevent unattended system changes and security risks; no passwordless grant. | Passwordless sudo for the provisioning user, because these VMs are snapshotted and disposable. |

\* On x1, Passage uses the attached 5C Nano instead of the travelling 5 NFC.
Its machine key is also an authentication fallback for the managed SSH
destinations, including Passage synchronization and GitHub SSH access.

Managed SSH configuration applies only to `github.com`,
`git.terroir.systems`, and `chalon`.
Chezmoi manages neither `git.terroir.systems` nor `chalon`; both are SSH
destinations only. Other hosts, aliases, and forwarding rules belong in
`~/.ssh/local_config`.

### VM sudo

`run_onchange_before_00-vm-sudo.sh.tmpl` installs a VM-only, root-owned
`0440` rule at `/etc/sudoers.d/99-chezmoi-<uid>` before package installation.
It validates the rule with `visudo` before activation and checks passwordless
sudo without a cached credential. The first apply needs a terminal and the
user's existing sudo password. No sudo grant is installed on remote servers;
administrators must remove any pre-existing passwordless grants there.
If reclassifying a VM as a non-VM, remove its sudoers rule manually first.

## SSH identity bootstrap

`run_after_10-ssh-identity.sh.tmpl` creates missing machine keys and registers
public keys with GitHub for `andreterroir`. Machine keys are signing keys;
x1 and VM machine keys are also authentication keys. On non-VM desktops it
downloads a missing resident key with `ssh-keygen -K` (touch and PIN) and
registers it for authentication and signing. On VMs it only registers
resident keys explicitly installed beforehand; non-VM servers skip them.

GitHub registration requires a terminal and account login. API outages are
tolerated when local keys already exist, but fail apply after creating a
key because registration is then required. Non-interactive VM/server apply
creates the machine key and defers registration to a terminal session.

VM/server machine keys have no passphrase, so unattended signing needs no
agent. Existing encrypted keys are never rewritten: apply stops with
instructions to run
`ssh-keygen -p -f ~/.ssh/id_ed25519` and leave the new passphrase empty.
This preserves the key and registrations. Desktop keys retain their
passphrase policy; see [Unlocking and agents](signing.md#unlocking-and-agents).

YubiKeys are optional on VMs: forward an agent containing an approved
resident key, or run `ssh-keygen -K` explicitly, save the pair as
`~/.ssh/id_ed25519_sk` and `~/.ssh/id_ed25519_sk.pub`, and load it with
`ssh-add ~/.ssh/id_ed25519_sk`. The approved list in `.chezmoidata.toml`
also supplies VM public-only files in `~/.ssh/identities/`, allowing
forwarded keys through SSH's identity filter without local resident-key
references. VM machine keys are not provisioned for password-server access.

## Amp runner

`run_after_30-amp-runner.sh.tmpl` enables the systemd user unit
`~/.config/systemd/user/amp-runner.service` on every Linux machine. It runs
`amp --no-tui` from `~/code`, names the runner after the machine's hostname,
serves `~/code/dotfiles` explicitly, and discovers the other checkouts beneath
`~/code`, so threads can be created on the machine from ampcode.com. Linger
keeps the runner up without a login, as it does for the servers' ssh-agent.
