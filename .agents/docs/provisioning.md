# Provisioning model

Chezmoi manages the shared configuration; machine-local overrides remain
untracked. See [AGENTS.md](../../AGENTS.md#machines) for the machine inventory
and [Commit signing](signing.md) for signing configuration and agent setup.

## Profile data

Init derives the data keys in `.chezmoi.toml.tmpl` from the machine and
persists them in `~/.config/chezmoi/chezmoi.toml`. Templates and `run_*`
scripts gate on these keys; the only hostname the set-up reads is the
`greenhouse` dev server. The three profile flags are exclusive by
construction, because one derivation writes all three; a config that lacks them
fails apply with "run chezmoi init before apply or update".

| Key | Chosen by | Selects |
| --- | --- | --- |
| `distro` | `.chezmoi.osRelease.id`; empty off Linux | the distro-specific package sets and gates |
| `vm` | the `managedVMs` list in `.chezmoidata.toml` | passwordless sudo, Ghostty's software-GL shims on Fedora desktops, and the profile's own tooling |
| `desktop` | `gnome-shell` on `PATH` | the desktop set-up in [Supported set-ups](#supported-set-ups) |
| `devserver` | the `greenhouse` hostname | the dev-server set-up |
| `transient` | a container, an Amp orb, or a hostname outside `managedHosts` | the portable set-up; see [Transient profile](transient.md) |

Every key is derived and none has a switch. Virtualization is not detected:
`vm` names the managed VMs, so a container, an orb, or an unlisted VM never
carries it and cannot reach the VM policy. `install.sh` passes its arguments to
`chezmoi apply`. Init persists the data, so a later bare `chezmoi apply` or
`chezmoi update` reuses it; run `chezmoi init` after changing a value or
upgrading the source, which also drops retired keys from the config.

A VM whose hostname is not in `managedHosts` is transient (see
[Transient profile](transient.md)); a managed VM such as `slate-vm-work`
keeps the machine-key policy below.

Linux desktops install KeePassXC. Templates derive the KeePass policy as
`desktop && !vm`, so dev servers, portable environments, and VMs
install no password manager. KeePassXC keeps its own settings, database, and
synchronization; this repository leaves `~/.config/keepassxc` unmanaged.

## Supported set-ups

A host that fits none of the other rows falls back to the portable set-up, so
nothing is refused: a managed host that is headless and is not `greenhouse`,
and any host that is not Linux, get the portable files and no provisioning.
The fallback is a safety net, not support: macOS remains an unsupported
platform that this repository does not provision.

| Set-up | Selected by | Installs | Configures | Identity and services |
| --- | --- | --- | --- | --- |
| desktop | a managed host with `gnome-shell` on `PATH` | the Fedora base CLI set, then Ghostty, GNOME extension support, KeePassXC, Syncthing, `wl-clipboard`, `yubikey-manager` and `pcsc-tools`; Flathub Signal, Telegram and Zotero, plus Spotify on x86_64 | shell, Vim, tmux, Git with the LFS filter, agent instructions, Ghostty and its two themes, tmux clipboard bindings, topgrade, mise with zig, exercism and rust, GNOME Shell extensions, the Firefox homepage policy, Syncthing autostart | passphrase-protected machine key and a downloaded YubiKey resident key, both registered on GitHub, signing on; existing sudo policy; `pcscd`; Amp runner |
| desktop, VM | `desktop` with `vm = true` | the desktop set minus KeePassXC and the resident-key download | the desktop configuration | passphrase-less machine key, passwordless sudo; Amp runner |
| devserver | the `greenhouse` hostname | the Ubuntu CLI set, `gh` from GitHub's apt repository, chezmoi from its installer, mise with zig, exercism and topgrade, opencode, the Amp CLI | shell, Vim, tmux, Git, agent instructions, the managed SSH configuration, topgrade and mise settings | passphrase-less machine key registered for signing only, no resident key, no sudo grant, no password manager; Amp runner |
| portable | a container, an Amp orb, a hostname outside `managedHosts`, any host that is not Linux, or a managed headless host that is not `greenhouse` | nothing | `~/.vimrc` with its plug snapshot, `~/.bin/git-cleanup`, `~/.agents/AGENTS.md`, `~/.config/AGENTS.md`; Vim plugins fetch from upstream | none: no keys, no allowlist, no runner, no sudo, no password manager, no packages |

The portable set-up leaves the host's shell, Git, and tmux configuration and
plugins unmanaged, along with `~/.gitignore`, `~/.bin/git-editor`, `~/.ssh`,
`~/.config/amp`, `~/.config/mise`, `~/.config/opencode`, `~/.config/systemd`,
`~/.config/topgrade.toml`, and the Claude, Codex, and Copilot homes. A harness
that owns those files, as an orb does, keeps its credential helper, hooks, and
environment loading.

## Package sources

Fedora takes Ghostty, mise, opencode-cli, and topgrade from Terra; Ubuntu takes
mise from mise's own apt repository. Fedora desktops skip Spotify on ARM
because its Flathub package is x86_64-only. Chezmoi downloads the two
configured Ghostty themes from a pinned upstream revision because Terra's
Ghostty package omits bundled themes.

A VM guest whose host OpenGL stops below 4.3 cannot run Ghostty's default
renderer: virgl exposes the host's ceiling, such as Apple's OpenGL 4.1, and
Ghostty requires 4.3. Fedora desktop VMs therefore get a drop-in for
`app-com.mitchellh.ghostty.service` and a `~/.bin/ghostty` wrapper, which
cover D-Bus and shell launches, setting `LIBGL_ALWAYS_SOFTWARE=1` to render
through llvmpipe and its OpenGL 4.6. systemd reads a drop-in only when it
loads the unit, so reload the user manager or log out once after the apply
that writes it. The gate does not probe the host, so a VM that could render
in hardware still gets the shims, and processes started from Ghostty inherit
the variable. Every other desktop keeps the accelerated renderer.

## Authentication and sudo

Credentials and sudo follow the set-up in the table above: KeePassXC and the
machine's own sudo policy on a desktop, no password manager and no passwordless
grant on a dev server, passwordless sudo on a VM, which is snapshotted and
disposable, and nothing at all in the portable set-up. A dev server takes remote
access through a forwarded resident key and has no machine-key access by
default. Every managed machine offers its default keys and whatever keys its
agent holds; registration decides what a server accepts.

x1 is the one exception: its attached 5C Nano provides the resident key instead
of the travelling 5 NFC, and its machine key is also registered for
authentication, including GitHub SSH access.

GitHub access is `gh` OAuth over HTTPS on every machine, x1 included: Git
reaches GitHub through the `gh` credential helper, so nothing depends on SSH
to GitHub. Only x1's machine key is registered as a GitHub authentication key;
no VM or other Linux desktop key is. Approved YubiKey resident keys stay
registered for authentication and signing on GitHub as hardware-backed
identities, not as a route for unattended access, so interactive SSH to GitHub
works wherever one is loaded, though no workflow needs it. Registration only
ever adds: a machine provisioned under an earlier policy keeps its key on the
account until it is removed by hand with `gh ssh-key delete`.

The managed SSH configuration offers this machine's identities to every host;
whether a key is authorized is the remote server's decision, so a machine key
authenticates wherever provisioning registered it. Aliases and forwarding rules
belong in `~/.ssh/local_config`. Chezmoi manages neither `git.terroir.systems`
nor `chalon`; both are SSH destinations only. A forwarded agent can hold more
keys than a server tries before it gives up (six attempts by default), so pin
an intended identity with `IdentityFile` and `IdentitiesOnly` in
`~/.ssh/local_config` for such a host.

### VM sudo

`run_onchange_before_00-vm-sudo.sh.tmpl` installs a VM-only, root-owned
`0440` rule at `/etc/sudoers.d/99-chezmoi-<uid>` before package installation.
It validates the rule with `visudo` before activation and checks passwordless
sudo without a cached credential. The first apply needs a terminal and the
user's existing sudo password. No sudo grant is installed on remote servers;
administrators must remove any pre-existing passwordless grants there.
If reclassifying a VM as a non-VM, remove its sudoers rule manually first.

## SSH identity bootstrap

`run_once_after_10-ssh-identity.sh.tmpl` creates missing machine keys and
registers public keys with GitHub for `andreterroir`. Transient environments
skip this section entirely; see [Transient profile](transient.md). Machine keys
are signing keys; x1's is the only one also registered as a GitHub
authentication key. On non-VM desktops it downloads a missing resident key
with `ssh-keygen -K` (touch and PIN) and registers it for authentication and
signing. On VMs it only registers resident keys explicitly installed beforehand;
non-VM servers skip them by policy.

A machine's identity does not change, so chezmoi runs the script once for each
version of its rendered content: a first apply, and again only when the script
or the data it renders changes. A provisioned machine passes without a
terminal, touching nothing. A step with work to do fails when it cannot be
done — generating a passphrase-protected key, downloading a resident key, or
registering keys with GitHub without a terminal, or any step whose GitHub is
unreachable or whose `gh` is missing — and the next apply retries it. A key
deleted after that run is therefore not recreated by an ordinary apply; see
[One-shot set-up scripts](#one-shot-set-up-scripts).

VM/server machine keys have no passphrase, so unattended signing needs no
agent. Existing encrypted keys are never rewritten: apply stops with
instructions to run
`ssh-keygen -p -f ~/.ssh/id_ed25519` and leave the new passphrase empty.
This preserves the key and registrations. Desktop keys retain their
passphrase policy; see [Unlocking and agents](signing.md#unlocking-and-agents).

YubiKeys are optional on VMs: forward an agent, or run `ssh-keygen -K`
explicitly, save the pair as `~/.ssh/id_ed25519_sk` and
`~/.ssh/id_ed25519_sk.pub`, and load it with `ssh-add ~/.ssh/id_ed25519_sk`.

## One-shot set-up scripts

`run_once_after_10-ssh-identity.sh.tmpl` above and
`run_once_after_allowed-signers.sh.tmpl` (see
[Commit signing](signing.md#verification)) are the repository's only `run_once_`
scripts. Clearing their state and applying re-runs both:

    chezmoi state delete-bucket --bucket=scriptState
    chezmoi apply

`scriptState` records every script, but `run_onchange_` runs are keyed in
`entryState`, which this leaves alone, so only these two re-run. Use it to
retry a failed run, to recreate a deleted machine key, and to refresh
`~/.allowed_signers` on the other machines after a machine registers a new
signing key: the file only reflects GitHub at the last completed run.

## GNOME Shell extensions

`run_onchange_set-up-gnome-shell-extensions.sh.tmpl` runs on Fedora desktops
and enables ddterm (the dropdown terminal), Window Navigator, Launch New
Instance, Night Theme Switcher, and AppIndicator support. Fedora packages all
but Night Theme Switcher, so `dnf` updates those. ddterm's `F12` default would
grab a key browsers use for DevTools, so the script sets its hotkey to
`Super+=`, which GNOME leaves unbound. Night Theme Switcher comes from
extensions.gnome.org, where each build targets one shell version: it is fetched
for the running shell and reinstalled whenever the script changes, which
includes a Fedora release upgrade; see [Fedora upgrades](upgrades.md). Enabling
writes the `org.gnome.shell` key the Shell watches, so a fresh install takes
effect at the next login.

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

`run_onchange_after_amp-runner.sh.tmpl` enables the systemd user unit
`~/.config/systemd/user/amp-runner.service` on every machine with a desktop or
dev-server profile. It runs
`amp --no-tui` from `~/code`, names the runner after the machine's hostname,
serves `~/code/dotfiles` explicitly, and discovers the other checkouts beneath
`~/code`, so threads can be created on the machine from ampcode.com. Linger
keeps the runner up without a login. Transient environments skip this setup;
see [Transient profile](transient.md).

`--remote-control-portals` gives every thread on the runner a Portal tab for
the dev servers and pages it starts, as orb threads have. A runner's portals
are not public and have no review button; this runner is not shared, so only
the Amp account opens them. The Amp apps' own **Allow Portals** switches stay
manual, so turning portals on for an app's runner remains the user's choice.

Running the runner on every non-transient machine, servers included, is
deliberate: threads must be able to reach every machine from ampcode.com.
The cost is that whoever controls that Amp account can run code on all of
them, and, through the VMs' passwordless sudo, as root on the VMs; share a
runner workspace only with people trusted on the machine.

Enabling is the script's work: it writes the unit's `default.target.wants` link
and turns linger on, which brings a user manager up at boot, so the runner
starts with the next boot or login. No apply step starts or restarts the runner
or reloads systemd of its own accord — `systemctl --user enable` re-reads the
unit files as part of enabling, which starts nothing — as
[AGENTS.md](../../AGENTS.md#apply-writes-configuration) requires, so an apply
never ends a thread that is running. A changed unit or setting takes effect the
next time the runner starts.

The script re-runs only when its own content changes, so an ordinary apply
leaves the runner alone. A runner stopped with `systemctl --user stop` comes
back when the user manager next starts; `systemctl --user disable` or `mask`
keeps it down, and linger removed by hand stays removed, until that script
changes or they undo it. Replacing the `amp` binary by hand, such as with a
reinstall or a manual upgrade, does not restart the runner either: the runner's
auto-update applies new releases itself.

A run that exits early, because `amp` is missing or no user manager answers,
still counts as done, so a later apply does not retry it: once the
precondition holds, enable and start the runner by hand with
`systemctl --user enable --now amp-runner.service`.

The runner updates itself by default
(`amp.runner.autoUpdate.enabled` is true): it installs new releases and
restarts into them once no thread is running, at most once every 12 hours.
With auto-update disabled, the runner keeps the release it started with until
it starts again, at the next boot or by hand.

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
