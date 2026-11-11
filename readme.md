Dotfiles & More
===============

Prerequisites
-------------

- curl
- git

This repository provisions Fedora desktops and one headless Ubuntu dev
server; containers and Amp orbs get a portable set-up with no packages and no
identity. macOS stays unsupported and is not provisioned: an apply there is
not refused, but it falls back to that portable set-up. See the
[Provisioning model](.agents/docs/provisioning.md#supported-set-ups) for the
exact scope.

Install
-------

    sh -c "$(curl -fsLS get.chezmoi.io)" -- init --apply --purge-binary --source=~/code/dotfiles andreterroir

This is for managed machines; add a new physical machine to
`managedHosts` (`.chezmoidata.toml`) before its full install. Elsewhere,
`./install.sh` from a clone of this repository applies the portable set-up: a
container, an orb, or an unlisted host gets Vim and agent instructions, with no
packages, and keeps its own shell, Git, and tmux configuration. See
[Transient profile](.agents/docs/transient.md).

A machine's identity set-up needs a human at the keyboard when it has work to
do: creating a passphrase-protected key, downloading the YubiKey's resident SSH
key, or logging in to GitHub. An apply without a terminal cannot do that, so
chezmoi reports the identity script as failed rather than skipping it, and
applying again from a terminal finishes it:

    chezmoi apply

That script and the signing allowlist run once; see
[One-shot set-up scripts](.agents/docs/provisioning.md#one-shot-set-up-scripts)
to run them again.

Git commit signing
------------------

Commits use the machine-local SSH key by default. See
[Commit signing](.agents/docs/signing.md) for repository-level YubiKey
overrides, agent setup, verification, and troubleshooting.

Provisioning
------------

The profile flags select the tooling; Linux desktops install KeePassXC, and
VMs keep their profile's tooling without password-manager apps. See the
[Provisioning model](.agents/docs/provisioning.md) for role detection, VM
configuration, credentials, sudo, package sources, and background services.

Vim plugins are pinned by `plug-snapshot.vim`; see
[Vim plugins](.agents/docs/vim-plugins.md) for the upgrade and verification
procedure.

Shortcuts
---------

Every key the configuration binds or overrides — Vim, tmux, Bash, git, Ghostty
and the GNOME window-management keys — is catalogued in
[Shortcuts](.agents/docs/shortcuts.md).

See [chezmoi](https://www.chezmoi.io/).
