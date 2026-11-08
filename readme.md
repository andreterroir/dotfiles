Dotfiles & More
===============

Prerequisites
-------------

- curl
- git

This repository manages macOS configuration plus Fedora and headless Ubuntu
provisioning. The macOS developer environment is out of scope: it installs no
Homebrew bundle or bootstrap, launchd SSH agent, Homebrew shell environment,
or PATH shims. The shared bash, git, ssh, tmux, Ghostty, vim, mise, opencode
and Amp configuration still applies to macOS.
Package install scripts target Fedora Linux and headless Ubuntu, so nothing
installs a Mac's applications.
Ubuntu servers get the CLI set only: no hugo, YubiKey, or Wayland clipboard
tools. Other distros are unsupported.
Fedora takes Ghostty, mise, opencode-cli, and topgrade from Terra; Ubuntu
takes mise from mise's own apt repository.
Fedora desktops skip Spotify on ARM because its Flathub package is x86_64-only.
Chezmoi downloads the two configured Ghostty themes from a pinned upstream
revision because Terra's Ghostty package omits bundled themes.

Install
-------

    sh -c "$(curl -fsLS get.chezmoi.io)" -- init --apply --purge-binary --source=~/code/dotfiles andreterroir

This is for managed machines. An orb, a container, or a hostname not listed in
`managedHosts` (`.chezmoidata.toml`) is transient: use the
[transient profile](#transient-environments), which `install.sh` and init
detect automatically. A VM is transient only when its hostname is not listed.
Add a new physical machine, a Mac included, to `managedHosts` before its full
install.

On physical Linux desktops, the first apply cannot finish on its own:
downloading the YubiKey's resident SSH key, logging in to GitHub, and
registering a key all need a human at the keyboard, and chezmoi prints what it
skipped. Run it again from a terminal to finish:

    chezmoi apply

Upgrading a Fedora desktop in place is covered in
[Fedora upgrades](.agents/docs/upgrades.md).

Transient environments
----------------------

An Amp orb, a container, or a hostname outside `managedHosts` — including a VM
— applies the full configuration inside that machine without changing anything
outside it:

    ./install.sh --transient

It installs packages, applies and enables services, and lays down the shell,
Git, Vim, tmux, and other file configuration. It creates no identity: no
SSH keys are generated or downloaded, nothing is registered with GitHub, no
signing allowlist is fetched, and `~/.gitconfig` omits `commit.gpgsign`,
`gpg.*`, and `user.signingKey`, so Amp's `/etc/gitconfig` still signs (or
commits stay unsigned elsewhere). SSH agent services are skipped, and a
non-interactive apply leaves the login shell unchanged.

`CHEZMOI_TRANSIENT` controls detection: any value except `0`/`false` forces
the profile, and `0`/`false` opts out. Without it, init enables the profile
for `AMP_ORB`, a Linux container, or a hostname not in `managedHosts` (see
`.chezmoidata.toml`). Known hosts, including a managed VM such as
`slate-vm-work`, keep the full profile; force the profile there with
`CHEZMOI_TRANSIENT=1`. The equivalent without `install.sh` is:

    CHEZMOI_TRANSIENT=1 chezmoi init --source=~/code/dotfiles
    chezmoi apply --source=~/code/dotfiles

See the [Transient profile](.agents/docs/transient.md) for details and
limits.

Git commit signing
------------------

Commits use the machine-local SSH key by default. See
[Commit signing](.agents/docs/signing.md) for repository-level YubiKey
overrides, agent setup, verification, and troubleshooting.

Provisioning
------------

Desktop/server role selects tooling; VMs keep that tooling but do not get
password-manager apps. A VM whose hostname is not in `managedHosts` is
transient; a managed VM keeps its machine key and provisioning. Linux
desktops install KeePassXC. KeePassXC user settings are managed, including
on macOS where the application is already present; the database is not, and
KeeShare settings are deliberately excluded.
See the [Provisioning model](.agents/docs/provisioning.md) for role
detection, VM configuration, credentials, sudo, and background services.
After changing `vm`, run `chezmoi init` before apply or update.

Vim plugins are pinned by `plug-snapshot.vim`. Applying a changed snapshot
reinstalls them at those commits, so installed plugins match the pin on every
machine. See [Vim plugins](.agents/docs/vim-plugins.md) for the upgrade
and verification procedure.

Shortcuts
---------

Every key the configuration binds — Vim and its plugins, tmux, Bash, git and
Ghostty — is catalogued in [Shortcuts](.agents/docs/shortcuts.md).

See [chezmoi](https://www.chezmoi.io/).
