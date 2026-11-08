Dotfiles & More
===============

Prerequisites
-------------

- curl
- git
- Homebrew on macOS

On a Mac, the apply installs `gh` and `jq` with Homebrew when they are missing:
the SSH identity script registers the machine key with gh, and the signing
allowlist is derived with jq. Bash, `curl`, and `ssh-keygen`, which the scripts
also call, ship with macOS. It also installs the Amp CLI with Amp's installer
and the Amp app with Homebrew; the app needs Apple silicon and macOS 26.

This repository manages macOS configuration plus Fedora and headless Ubuntu
provisioning. The macOS developer environment is out of scope: it installs no
Homebrew bundle or bootstrap, launchd SSH agent, Homebrew shell environment,
or PATH shims. gh, jq and Amp are the only tools a Mac's apply installs; a
Mac gets the shared bash, git, ssh, tmux, Ghostty, vim and Amp configuration,
but no configuration for the developer tools only Linux provisions: mise,
opencode, topgrade and git-lfs.
Package install scripts target Fedora Linux and headless Ubuntu; on a Mac,
nothing else installs applications.
Ubuntu servers get the CLI set only: no hugo, YubiKey, Wayland clipboard
tools, or Ghostty, whose terminfo they install without its configuration.
Other distros are unsupported.
Fedora takes Ghostty, mise, opencode-cli, and topgrade from Terra; Ubuntu
takes mise from mise's own apt repository.
Fedora desktops skip Spotify on ARM because its Flathub package is x86_64-only.
Chezmoi downloads the two configured Ghostty themes from a pinned upstream
revision because Terra's Ghostty package omits bundled themes.

Install
-------

    sh -c "$(curl -fsLS get.chezmoi.io)" -- init --apply --purge-binary --source=~/code/dotfiles andreterroir

This is for managed machines; elsewhere use the
[transient profile](#transient-environments). Add a new physical machine, a Mac
included, to `managedHosts` (`.chezmoidata.toml`) before its full install.

On physical Linux desktops, the first apply cannot finish on its own:
downloading the YubiKey's resident SSH key, logging in to GitHub, and
registering a key all need a human at the keyboard, and chezmoi prints what it
skipped. Run it again from a terminal to finish:

    chezmoi apply

Upgrading Fedora
----------------

Fedora desktops upgrade in place with dnf5's `system-upgrade` command; replace
both release numbers for the next upgrade:

    sudo dnf upgrade --refresh
    sudo systemctl reboot

After the reboot, download the new release and start the offline upgrade:

    sudo dnf system-upgrade download --releasever=45
    sudo dnf system-upgrade reboot

Then re-apply the configuration:

    chezmoi apply

Fedora retires packages between releases. Drop those retired since the old
release, with `remove-retired-packages` from the package set:

    sudo remove-retired-packages 44

The `chezmoi apply` above also downloads Night Theme Switcher for the new
shell, because `run_onchange_set-up-gnome-shell-extensions.sh.tmpl` records the
Fedora release. Log out and back in so the Shell loads it, then confirm with:

    gnome-extensions info nightthemeswitcher@romainvigier.fr

Since Fedora 45, oo7 provides the Secret Service instead of GNOME Keyring, and
an upgraded machine can keep both running. gcr-ssh-agent keeps the machine
key's passphrase in that service, so check which daemon answers with
`busctl --user status org.freedesktop.secrets`.

Transient environments
----------------------

A machine that may be discarded — an Amp orb, a container, or a hostname
outside `managedHosts` — applies the full configuration inside itself:

    ./install.sh --transient

See the [Transient profile](.agents/docs/transient.md) for detection,
`CHEZMOI_TRANSIENT`, what runs, and the limits.

Git commit signing
------------------

Commits use the machine-local SSH key by default. See
[Commit signing](.agents/docs/signing.md) for repository-level YubiKey
overrides, agent setup, verification, and troubleshooting.

Provisioning
------------

Desktop/server role selects tooling; VMs keep that tooling but do not get
password-manager apps. Linux desktops install KeePassXC. KeePassXC user
settings are managed, including on macOS where the application is already
present; the database is not, and KeeShare settings are deliberately excluded.
See the [Provisioning model](.agents/docs/provisioning.md) for role
detection, VM configuration, credentials, sudo, and background services.
After changing `vm`, run `chezmoi init` before apply or update.

Vim plugins are pinned by `plug-snapshot.vim`. Applying a changed snapshot
reinstalls them at those commits, so installed plugins match the pin on every
machine. See [Vim plugins](.agents/docs/vim-plugins.md) for the upgrade
and verification procedure.

Shortcuts
---------

Every key the configuration binds or overrides — Vim, tmux, Bash, git and
Ghostty — is catalogued in [Shortcuts](.agents/docs/shortcuts.md).

See [chezmoi](https://www.chezmoi.io/).
