# Provisioning model

Chezmoi manages the shared configuration; machine-local overrides remain
untracked. See [AGENTS.md](../../AGENTS.md#machines) for the machine inventory
and [Commit signing](signing.md) for signing configuration and agent setup.

## Profile data

Init derives the data keys in `.chezmoi.toml.tmpl` from the machine and
persists them in `~/.config/chezmoi/chezmoi.toml`; templates and `run_*`
scripts gate on them. A config without the three profile flags or `work` fails
apply with "run chezmoi init before apply or update", and no key has a switch.

| Key | Chosen by | Selects |
| --- | --- | --- |
| `distro` | `.chezmoi.osRelease.id`; empty off Linux | the distro-specific package sets and gates |
| `vm` | the `managedVMs` list in `.chezmoidata.toml` | passwordless sudo, Ghostty's software-GL shims, and keeping KeePassXC, Syncthing, and the Flathub apps off the machine |
| `work` | the `workMachines` list in `.chezmoidata.toml` | the keys a machine registers with the personal GitHub account, and whether it deploys the Amp runner |
| `desktop` | `gnome-shell` on `PATH` | the desktop set-up |
| `devserver` | the `greenhouse` hostname | the dev-server set-up |
| `transient` | a container, an Amp orb, or a hostname outside `managedHosts` | the portable set-up |

One derivation writes the three profile flags, so they exclude each other.
Virtualization is not detected: `vm` names the managed VMs, so an unlisted VM
is transient and never reaches the VM policy. Init persists the data, so a
change to a value or to the source needs `chezmoi init` again; `install.sh`
passes its arguments to `chezmoi apply`.

KeePassXC is installed on Linux desktops only, derived as `desktop && !vm`. It
keeps its own settings and database, so `~/.config/keepassxc` stays unmanaged.

## Set-ups

A host that fits no row gets the portable set-up and nothing else: it is not
refused, and what an earlier apply left there stays.

| Set-up | Selected by | Installs | Configures | Identity and services |
| --- | --- | --- | --- | --- |
| desktop | a managed host with `gnome-shell` on `PATH` | the Fedora base CLI set, then Ghostty, GNOME extension support, KeePassXC, Syncthing, `wl-clipboard`; Flathub Signal, Telegram and Zotero, plus Spotify on x86_64 | shell, Vim, tmux, Git with the LFS filter, agent instructions, Ghostty and its themes, topgrade, mise with zig, exercism and rust, GNOME Shell extensions, the Firefox homepage policy, Syncthing autostart | passphrase-protected machine key registered on GitHub for signing; existing sudo policy; Amp runner |
| desktop, VM | `desktop` with `vm = true` | the desktop set minus KeePassXC, Syncthing, and the Flathub apps | the desktop configuration, minus the Syncthing autostart entry | passphrase-less machine key registered on GitHub for signing, passwordless sudo; Amp runner, except on a `work` machine |
| devserver | the `greenhouse` hostname | the Ubuntu CLI set, `gh`, chezmoi, mise with zig, exercism and topgrade, opencode, the Amp CLI | shell, Vim, tmux, Git, agent instructions, the managed SSH configuration, topgrade and mise settings | passphrase-less machine key registered for signing only, no sudo grant, no password manager; Amp runner |
| portable | a container, an Amp orb, a hostname outside `managedHosts`, or a host that is not Linux | nothing | `~/.vimrc` with its plug snapshot, `~/.bin/git-cleanup`, the agent instructions | none: no keys, no allowlist, no runner, no sudo, no packages |

`work` changes the identity and the runner, and nothing else: the machine
keeps its profile's installs, configuration, and services, creates its machine
key, registers nothing with the personal GitHub account, and deploys no
[Amp runner](#amp-runner). `slate-vm-work` is the only one today.

## Portable set-up

A container, an Amp orb, or an unlisted host may be discarded, so it receives
only files that apply anywhere. `chezmoi init` derives the profile from the
machine; there is no flag to force it. Run `./install.sh` with `HOME` set to
the throwaway home, because the apply writes into `$HOME`; other arguments go
to `chezmoi apply`.

- Vim and its pinned plugins, `~/.bin/git-cleanup`, the agent instructions at
  `~/.agents/AGENTS.md` and `~/.config/AGENTS.md`, and the `~/cs` link wherever
  `~/Sync/cheatsheets` exists are the whole set-up. The package, sudo, and mise
  scripts render empty, and the tmux plugin script does not run.
- The host keeps its own shell, Git, and tmux configuration: `~/.bashrc`,
  `~/.bash_profile`, `~/.gitconfig`, `~/.tmux.conf`, `~/.gitignore`, and
  `~/.bin/git-editor` stay as they are. A harness that owns those files keeps
  its credential helper, hooks, and environment loading.
- `~/.ssh`, `~/.config/amp`, `~/.config/mise`, `~/.config/opencode`,
  `~/.config/systemd`, and `~/.config/topgrade.toml` stay unmanaged, so a
  forwarded agent and the platform's own tool settings keep working.
- Vim plugins come from their upstream repositories, so a first apply needs
  network access; the script skips when Vim is absent.
- No key, allowlist, agent unit, or runner is created, and nothing registers
  with GitHub or ampcode.com: authentication comes from the environment, such
  as a forwarded agent. This profile writes no `~/.gitconfig`, so an existing
  one keeps its own signing settings, as does an environment-provided
  configuration such as Amp's `/etc/gitconfig`; without either, commits are
  unsigned.
- Material an earlier profile left in the home is not removed: start from a
  fresh home, or delete the keys, allowlist, and agent units yourself.

`managedHosts` lists the chezmoi targets as lowercase short hostnames,
compared after stripping a `.local` suffix. Add a physical machine before its
first full apply, and run `chezmoi init` after changing the list. An absent
list makes every host transient.

## SSH identity

`run_once_after_10-ssh-identity.sh.tmpl` creates a missing machine key and
registers its public key with GitHub for `andreterroir`, as a signing key. A
desktop keeps its passphrase; VM and server keys are created without one, and
an existing encrypted key there stops the script with instructions to run
`ssh-keygen -p -f ~/.ssh/id_ed25519` and leave the new passphrase empty.

Machine keys are the identity remote servers authorize. Every managed machine
offers `~/.ssh/id_ed25519`, and a server accepts it once that public key is in
the remote account's `~/.ssh/authorized_keys`. Enrolling one is manual: this
repository does not manage `~/.ssh/authorized_keys` anywhere. Aliases and
forwarding rules belong in `~/.ssh/local_config`; a forwarded agent can hold
more keys than a server tries (six attempts by default), so pin an intended
identity there with `IdentityFile` and `IdentitiesOnly`.

A `work` machine stops after creating its key: no `gh` login, no registration,
and nothing about it reaches the personal GitHub account. Its commits sign
with that key and verify only where `~/.allowed_signers` lists it, and a
refresh rebuilds that file from GitHub's keys, so an entry added by hand is
lost and GitHub shows the commits unverified. The flag stops future
registration only, so a machine marked `work` later keeps what it registered
until `gh ssh-key delete`.

Registration takes two browser confirmations: a login that grants the
`admin:ssh_signing_key` scope, and a refresh that drops it again, because
GitHub fixes a token's scopes when it issues it. Where the session has a
clipboard `gh` can write to, it copies the one-time code, so the step is a
paste; else the code is printed to retype. A run that has to register and
cannot reach GitHub, or cannot find `gh`, fails, and the next apply retries it.

## One-shot set-up scripts

The identity script above and `run_once_after_allowed-signers.sh.tmpl` (see
[Commit signing](signing.md#verification)) are the repository's only `run_once_`
scripts, and each runs once per version of its rendered content. Clearing their
state re-runs both:

    chezmoi state delete-bucket --bucket=scriptState
    chezmoi apply

`scriptState` records every script, but `run_onchange_` runs are keyed in
`entryState`, which this leaves alone. Use it to retry a failed run, to
recreate a deleted machine key, and to refresh `~/.allowed_signers` after a
machine registers a new signing key.

## VM sudo

`run_onchange_before_00-vm-sudo.sh.tmpl` installs a VM-only, root-owned `0440`
rule at `/etc/sudoers.d/99-chezmoi-<uid>` before package installation. It
validates the rule with `visudo` before activation and checks passwordless
sudo without a cached credential, so the first apply needs a terminal and the
user's existing sudo password. No sudo grant is installed on remote servers;
remove any pre-existing grant there, or on a VM reclassified as a non-VM,
before applying again.

## Packages and sources

Fedora takes Ghostty, mise, opencode-cli, and topgrade from Terra, whose main
repository is enough: do not enable `terra-release-extras`, `-mesa`, or
`-multimedia`. Ubuntu takes mise from mise's own apt repository, and `gh` from
GitHub's, because Ubuntu's package is stale. Chezmoi's installer writes its
binary into `~/.local/bin`; opencode's installer cannot change `PATH`, so the
script links its binary there too. Ubuntu's `fd-find` package provides
`fdfind`, so the script links that name as `fd`. Chezmoi downloads the two
configured Ghostty themes from a pinned upstream revision, because Terra's
Ghostty package omits bundled themes. Fedora desktops skip Spotify on ARM,
where its Flathub package is x86_64-only.

Fedora ships `start.fedoraproject.org` as the homepage default that every
Firefox update restores, so `run_onchange_firefox-homepage-policy.sh.tmpl`
installs `about:home` as a system policy in `/etc/firefox/policies/policies.json`.
No RPM owns that file, so updates leave it alone, and the setting stays
unlocked.

A VM guest whose host OpenGL stops below 4.3 cannot run Ghostty's default
renderer: virgl exposes the host's ceiling, such as Apple's OpenGL 4.1, and
Ghostty requires 4.3. Fedora desktop VMs therefore get a drop-in for
`app-com.mitchellh.ghostty.service` and a `~/.bin/ghostty` wrapper, covering
D-Bus and shell launches, with `LIBGL_ALWAYS_SOFTWARE=1` rendering through
llvmpipe and its OpenGL 4.6. The gate does not probe the host. systemd reads a
drop-in only when it loads the unit, so reload the user manager or log out
once after the apply that writes it.

## GNOME Shell extensions

`run_onchange_set-up-gnome-shell-extensions.sh.tmpl` runs on Fedora desktops
and enables ddterm (the dropdown terminal), Window Navigator, Launch New
Instance, Night Theme Switcher, and AppIndicator support. Fedora packages all
but Night Theme Switcher, so `dnf` updates those. Night Theme Switcher comes
from extensions.gnome.org, where each build targets one shell version: it is
fetched for the running shell and reinstalled whenever the script changes,
which includes a Fedora release upgrade. Enabling writes the `org.gnome.shell`
key the Shell watches, so a fresh install takes effect at the next login.

## Syncthing

`run_onchange_install-linux-packages.sh.tmpl` installs Syncthing on Fedora
desktops that are not VMs, and
`private_dot_config/autostart/symlink_syncthing-start.desktop` registers the
packaged launcher with XDG autostart. Devices and folders stay unmanaged: each
host keeps its own device key and a config Syncthing rewrites at runtime, under
`~/.local/state/syncthing`.

The `obsidian` device is the standard introducer: mark it as one on every
desktop, and it shares Sync, Documents, and notes. An introducer adds a device
only to folders it already shares with the receiver and never creates folders,
so accept its folder offers in the new machine's GUI; a folder created by hand
gets a new folder ID that never syncs. `archive` is outside obsidian's
folders: share it from x1 or black, and accept that offer too.

`symlink_cs.tmpl` links `~/cs` to `~/Sync/cheatsheets` on any machine where
that folder exists, and creates nothing where it does not.

## tmux plugins

`.chezmoitemplates/tmux-plugins` holds the plugin list that
`dot_tmux.conf.tmpl` includes, and `run_onchange_after_tmux-plugins.sh.tmpl`
checksums it, so adding a plugin re-runs the installer. The script installs
TPM when it is missing, then clones whatever `@plugin` lines are missing. A
server started before TPM loaded has no `TMUX_PLUGIN_MANAGER_PATH`, which the
installer needs, so the script sets it, and it stops a server it started,
because loading the configuration can restore a session.

## Amp runner

`run_onchange_after_amp-runner.sh.tmpl` enables the systemd user unit
`~/.config/systemd/user/amp-runner.service` on every machine with a desktop or
dev-server profile, except a `work` machine. It runs `amp --no-tui` from
`~/code`, names the runner after the hostname, serves `~/code/dotfiles` and
discovers the other checkouts beneath `~/code`, so threads can be created on
the machine from ampcode.com. Linger keeps it up without a login, and the unit
puts `~/.bash_profile`'s user directories on `PATH`, because a thread inherits
the service's environment rather than a login shell's.

A `work` machine is gated rather than torn down: chezmoi stops deploying the
unit and the script, but a machine that already ran a runner keeps it, and its
linger, until `systemctl --user disable --now amp-runner.service` and
`loginctl disable-linger` run there. Dropping a machine from `workMachines`
restores the unit but does not re-run the script, so enable it by hand.

Enabling is the script's work: it writes the unit's `default.target.wants`
link and turns linger on, so the runner starts with the next boot or login. No
apply step starts or restarts it, as
[AGENTS.md](../../AGENTS.md#apply-writes-configuration) requires. A run that
exits early, because `amp` is missing or no user manager answers, counts as
done, so enable the runner by hand once the precondition holds. The runner
updates itself, installing new releases and restarting into them once no
thread is running, at most once every 12 hours.

`--remote-control-portals` gives every thread on the runner a Portal tab for
the dev servers and pages it starts. A runner's portals are not public and
have no review button; this runner is not shared, so only the Amp account opens
them, and the Amp apps' **Allow Portals** switches stay manual.

Running the runner on every non-transient machine is deliberate, so threads
reach every machine from ampcode.com. The cost is that whoever controls that
Amp account can run code there, and as root through a VM's passwordless sudo;
share a runner workspace only with people trusted on the machine.

`private_dot_config/private_amp/modify_settings.json` enables
`amp.runner.env.enabled`, so runner threads get the Secrets & Env Vars
configured on ampcode.com, as orb threads do. The script merges the managed
keys into the file the CLI owns: it writes that file when it is empty, and
needs `jq` to merge an existing one, so a first apply that runs before the
package script installs `jq` leaves a non-empty file alone and the next apply
merges it. Every thread on the runner can read those variables,
including threads created remotely; a runner shared with `--share` injects
only the workspace and project values.
