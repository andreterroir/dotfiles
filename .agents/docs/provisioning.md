# Provisioning model

Chezmoi manages the shared configuration; machine-local overrides remain
untracked. See [AGENTS.md](../../AGENTS.md#machines) for the machine inventory
and [Commit signing](signing.md) for signing configuration and agent setup.

## Roles and profile data

Init derives the data keys in `.chezmoi.toml.tmpl` from the machine and
persists them in `~/.config/chezmoi/chezmoi.toml`. Templates and `run_*`
scripts gate on these keys, never on a hostname. A config whose `transient`
key is missing fails apply with "run chezmoi init before apply or update".

| Key | Chosen by | Selects |
| --- | --- | --- |
| `distro` | `.chezmoi.osRelease.id` on Linux, `darwin` on macOS, empty elsewhere | the distro-specific package sets and gates |
| `desktop` | true on macOS, and on Linux with `gnome-shell` on `PATH` | the desktop profile, and the resident YubiKey key on Linux |
| `linux.desktop` | `desktop` on Linux | the Linux desktop package set and Flatpaks, GNOME Shell extensions, the Firefox homepage policy, Syncthing autostart, tmux clipboard bindings, and the gcr SSH agent socket |
| `server` | `!desktop` | the headless package set, and topgrade on Ubuntu servers via mise |
| `vm` | `systemd-detect-virt --vm` on Linux, otherwise false; override by setting `vm` in the chezmoi config | passwordless sudo, YubiKey public-only identities for forwarded keys, and the role's own tooling |
| `transient` | `./install.sh --transient`, or `CHEZMOI_TRANSIENT` (`0`/`false` opts out), else detection below | identity agents, machine keys, signing, the Amp runner, and the macOS `gh` and `jq` install; see [Transient profile](transient.md) |

`desktop`, `linux.desktop`, and `server` are derived and have no switch. `vm`
and the transient profile do: set `vm` in `~/.config/chezmoi/chezmoi.toml`,
run `./install.sh --transient`, or set `CHEZMOI_TRANSIENT`. `install.sh`
passes every other argument to `chezmoi apply`. Init persists the data, so a
later bare `chezmoi apply` or `chezmoi update` reuses it; run `chezmoi init`
after changing `vm` or upgrading the source, which also drops retired keys
from the config.

A VM whose hostname is not in `managedHosts` is transient (see
[Transient profile](transient.md)); a managed VM such as `slate-vm-work`
keeps the machine-key policy below.

Linux desktops install KeePassXC. Templates derive the KeePass policy as
`desktop && !vm`, so servers and VMs install no password manager. KeePassXC
user settings are
managed at `~/.config/keepassxc/keepassxc.ini` on Linux and at
`~/Library/Application Support/KeePassXC/keepassxc.ini` on macOS, where the
application itself is not provisioned. Apply merges the managed keys over
the file, so the keys KeePassXC writes at runtime survive. KeeShare
settings are deliberately omitted and not merged. Neither the database nor
its synchronization is provisioned here.

## Package sources

Fedora takes Ghostty, mise, opencode-cli, and topgrade from Terra; Ubuntu takes
mise from mise's own apt repository. Fedora desktops skip Spotify on ARM
because its Flathub package is x86_64-only. Chezmoi downloads the two
configured Ghostty themes from a pinned upstream revision because Terra's
Ghostty package omits bundled themes.

## Authentication and sudo

VM policy takes precedence over the other columns.

| Aspect | Fedora desktop | Headless server | VM (desktop or headless) |
| --- | --- | --- | --- |
| Passwords | KeePassXC; the database is not managed here. | No password manager is provisioned. | No password manager is provisioned. |
| Remote server access | Use a resident key and forward its agent.\* | Use a forwarded resident key for onward access; no machine-key access is provisioned by default. | Use an explicitly installed or forwarded resident key; no machine-key fallback is configured for managed remote servers. |
| GitHub access | `gh` OAuth and HTTPS.\* | `gh` OAuth and HTTPS. | `gh` OAuth and HTTPS. |
| Sudo | Existing system policy; no passwordless grant. | Must require a password to prevent unattended system changes and security risks; no passwordless grant. | Passwordless sudo for the provisioning user, because these VMs are snapshotted and disposable. |

\* On x1, the attached 5C Nano provides the resident key instead of the
travelling 5 NFC. Its machine key is also an authentication fallback for the
managed SSH destinations and GitHub SSH access, the one exception to the
policy below.

GitHub access is `gh` OAuth over HTTPS on every machine, x1 included: Git
reaches GitHub through the `gh` credential helper, so nothing depends on SSH
to GitHub. Only x1's machine key is registered as a GitHub authentication key;
no VM, Mac, or other Linux desktop key is. Approved YubiKey resident keys stay
registered for authentication and signing on GitHub as hardware-backed
identities, not as a route for unattended access, so interactive SSH to GitHub
works wherever one is loaded, though no workflow needs it. Registration only
ever adds: a machine provisioned under an earlier policy keeps its key on the
account until it is removed by hand with `gh ssh-key delete`.

macOS gets none of the Linux provisioning above: this repository manages no
Homebrew bundle, SSH agent, or YubiKey resident key there (Apple's OpenSSH
has no FIDO provider). It manages the shared configuration, the KeePassXC
settings, and the iCloud notes symlink, and it creates and registers the
machine key on GitHub for signing only. A Mac reaches GitHub through `gh` over
HTTPS and uses its machine key for `git.terroir.systems` and `chalon`, where a
YubiKey resident key cannot work.

`run_onchange_install-macos-tools.sh.tmpl` installs `gh`, for first key
registration, and `jq`, to derive `~/.allowed_signers`, with the Mac's
existing Homebrew when either is missing. It also installs the Amp CLI with
Amp's installer, unless an `amp` is already on PATH, and the `amp-app` cask on
Apple silicon with macOS 26 or later; those are the only tools a Mac's apply
installs. Nothing provisions mise, opencode, topgrade or git-lfs there, so
`.chezmoiignore.tmpl` and the Git configuration leave their settings off macOS
too. Each signing script still names its own missing tool and fails before the
remaining scripts run, because registration and the allowlist are part of
signing.

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
public keys with GitHub for `andreterroir`. Transient environments skip this
section entirely; see [Transient profile](transient.md). Machine keys are
signing keys; x1's is the only one also registered as a GitHub authentication
key. On non-VM Linux desktops it downloads a missing resident key with
`ssh-keygen -K` (touch and PIN) and registers it for authentication and
signing. On VMs it only registers resident keys explicitly installed
beforehand; non-VM servers skip them by policy, and macOS cannot provision one
because Apple's OpenSSH has no FIDO provider. A Mac reaches GitHub through `gh`
over HTTPS and authenticates to `git.terroir.systems` and `chalon` with its
machine key.

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
reinstalled whenever the script changes, which includes a Fedora release
upgrade; see [Fedora upgrades](upgrades.md). Enabling writes the
`org.gnome.shell` key the Shell watches, so a fresh install takes effect at the
next login.

## Syncthing

`run_onchange_install-linux-packages.sh.tmpl` installs Syncthing on Fedora
desktops, and `private_dot_config/autostart/symlink_syncthing-start.desktop`
registers the packaged launcher with XDG autostart. Devices and folders stay
unmanaged: each host keeps its own device key and a config Syncthing rewrites
at runtime, under `~/.local/state/syncthing`.

The `obsidian` device is the standard introducer: mark it as one on every
desktop, and it shares Sync, Documents, and notes. An introducer adds a
device only to folders it already shares with the receiver and never
creates folders, so accept obsidian's folder offers in the new machine's
GUI; creating a folder by hand assigns a new folder ID that never syncs.
Desktops that mark obsidian as an introducer pick up the new device in
those folders without pairing with the new machine. `archive` is outside
obsidian's folders: share it from x1 or black, and accept that offer too.

## Amp runner

`run_onchange_after_30-amp-runner.sh.tmpl` enables the systemd user unit
`~/.config/systemd/user/amp-runner.service` on every Linux machine. It runs
`amp --no-tui` from `~/code`, names the runner after the machine's hostname,
serves `~/code/dotfiles` explicitly, and discovers the other checkouts beneath
`~/code`, so threads can be created on the machine from ampcode.com. Linger
keeps the runner up without a login. Transient environments skip this setup;
see [Transient profile](transient.md).

Running the runner on every non-transient machine, servers included, is
deliberate: threads must be able to reach every machine from ampcode.com.
The cost is that whoever controls that Amp account can run code on all of
them, and, through the VMs' passwordless sudo, as root on the VMs; share a
runner workspace only with people trusted on the machine.

The script re-runs when the unit, Amp's settings, or the script itself
changes: header comments checksum the unit file and
`~/.config/amp/settings.json`, and chezmoi re-runs a `run_onchange_` script
only when its content changes. On a re-run it restarts the runner if it is
active and starts it if it is stopped, so changing a runner setting such as
`amp.runner.env.enabled` restarts the runner once. A restart ends any thread
running at the time, so apply while the runner is idle.

An apply that leaves the unit and settings unchanged does not run the script
at all, which changes two behaviors. Replacing the `amp` binary by hand, such
as with a reinstall or a manual upgrade, no longer restarts the runner, since
the runner's auto-update applies new releases itself. And a deliberately
stopped runner stays stopped unless the unit or settings change or it is
started by hand, as do a runner disabled with `systemctl --user disable` and
linger removed by hand.

A run that exits early, because `amp` is missing or no user manager answers,
still counts as done, so a later apply does not retry it: once the
precondition holds, enable and start the runner by hand with
`systemctl --user enable --now amp-runner.service`.

The runner updates itself by default
(`amp.runner.autoUpdate.enabled` is true): it installs new releases and
restarts into them once no thread is running, at most once every 12 hours.
With auto-update disabled, apply supplies a restart only when the unit or
settings change.

`private_dot_config/private_amp/modify_settings.json` enables
`amp.runner.env.enabled`, so runner threads get the Secrets & Env Vars
configured on ampcode.com, as orb threads do. The runner fetches them when a
thread starts and injects them into the thread's shell commands, MCP servers,
and plugins, so changing a value on ampcode.com needs no runner restart.
Every thread on the runner can read those variables, including threads
created remotely. A runner shared with `--share` injects only the workspace
and project values; personal values are not injected at all, including into
your own threads on it. Share a runner only with people trusted to run code
on the machine, and keep credentials that only some threads should see out of
the shared set.
