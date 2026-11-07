# Provisioning model

Chezmoi manages the shared configuration; machine-local overrides remain
untracked. See [AGENTS.md](../../AGENTS.md#machines) for the machine inventory
and [Commit signing](signing.md) for signing configuration and agent setup.

## Roles and password managers

Init derives `desktop` without prompting: true on macOS and on Linux with
`gnome-shell` on PATH. `server` is its inverse; `linux.desktop` identifies
Linux desktops. Role selects tools and the SSH agent, not a hostname.

`vm` is independent of role. Linux init detects it with
`systemd-detect-virt --vm` unless already configured, preserving the value on
subsequent init runs. On other platforms it defaults to false and can be
set in the chezmoi config. VMs retain desktop/server tooling.

Desktops install KeePassXC, and macOS also installs KeePassium from the Mac
App Store. Init derives `keepass` as `desktop && !vm` to select both apps, so
servers and VMs install no password manager. KeePassXC user settings are
managed at `~/.config/keepassxc/keepassxc.ini` on Linux and
`~/Library/Application Support/KeePassXC/keepassxc.ini` on macOS. Apply
replaces the whole file, so KeeShare settings are deliberately omitted and
any local KeeShare key is discarded. Neither the database nor its
synchronization is provisioned here.

Run `chezmoi init` before apply/update after changing `vm` so the derived data
is recomputed. Init also rewrites `~/.config/chezmoi/chezmoi.toml`, so run it
after upgrading the source to drop retired data keys and hooks.

## Authentication and sudo

VM policy takes precedence over the other columns.

| Aspect | macOS desktop | Fedora desktop | Headless server | VM (desktop or headless) |
| --- | --- | --- | --- | --- |
| Passwords | KeePassXC and KeePassium; the database is not managed here. | KeePassXC; the database is not managed here. | No password manager is provisioned. | No password manager is provisioned. |
| Remote server access | Use a resident key and forward its agent. | Use a resident key and forward its agent.\* | Use a forwarded resident key for onward access; no machine-key access is provisioned by default. | Use an explicitly installed or forwarded resident key; no machine-key fallback is configured for managed remote servers. |
| GitHub access | `gh` OAuth and HTTPS provide unattended access; a resident key provides SSH access. | `gh` OAuth and HTTPS provide unattended access; a resident key provides SSH access.\* | `gh` OAuth and HTTPS provide unattended access; a forwarded resident key provides SSH access. | `gh` OAuth and HTTPS are available; SSH accepts an approved resident key or the VM machine key. |
| Sudo | Existing system policy; no passwordless grant. | Existing system policy; no passwordless grant. | Must require a password to prevent unattended system changes and security risks; no passwordless grant. | Passwordless sudo for the provisioning user, because these VMs are snapshotted and disposable. |

\* On x1, the attached 5C Nano provides the resident key instead of the
travelling 5 NFC. Its machine key is also an authentication fallback for the
managed SSH destinations and GitHub SSH access.

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
references.

## GNOME Shell extensions

`run_onchange_set-up-gnome-shell-extensions.sh.tmpl` runs on Fedora desktops
and enables Window Navigator, Launch New Instance, Night Theme Switcher, and
AppIndicator support. Fedora packages all but Night Theme Switcher, so `dnf`
updates those. Night Theme Switcher comes from extensions.gnome.org, where each
build targets one shell version: it is fetched for the running shell and
reinstalled whenever the script changes. Enabling writes the `org.gnome.shell`
key the Shell watches, so a fresh install takes effect at the next login.

## Amp runner

`run_after_30-amp-runner.sh.tmpl` enables the systemd user unit
`~/.config/systemd/user/amp-runner.service` on every Linux machine. It runs
`amp --no-tui` from `~/code`, names the runner after the machine's hostname,
serves `~/code/dotfiles` explicitly, and discovers the other checkouts beneath
`~/code`, so threads can be created on the machine from ampcode.com. Linger
keeps the runner up without a login, as it does for the servers' ssh-agent.
