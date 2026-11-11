Dotfiles & More
===============

Prerequisites
-------------

- curl
- git
- Homebrew on macOS

On a Mac, the apply installs `gh` and `jq` with Homebrew when they are missing,
and adds the Amp CLI and the Amp app; the app needs Apple silicon and macOS 26.

This repository manages macOS configuration plus Fedora and headless Ubuntu
provisioning; other distros are unsupported. A Mac gets the shared
configuration and none of the Linux developer tooling; the Mac's apply
installs only `gh`, `jq`, and the Amp CLI and app. See the
[Provisioning model](.agents/docs/provisioning.md) for the exact scope.
Ubuntu servers get the CLI set only.

Install
-------

    sh -c "$(curl -fsLS get.chezmoi.io)" -- init --apply --purge-binary --source=~/code/dotfiles andreterroir

This is for managed machines; add a new physical machine, a Mac included, to
`managedHosts` (`.chezmoidata.toml`) before its full install. Elsewhere, run
`./install.sh --transient` from a clone of this repository; see
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

Desktop/server role selects tooling; Linux desktops install KeePassXC, and VMs
keep the role's tooling without password-manager apps. See the
[Provisioning model](.agents/docs/provisioning.md) for role detection, VM
configuration, credentials, sudo, package sources, and background services.

Vim plugins are pinned by `plug-snapshot.vim`; see
[Vim plugins](.agents/docs/vim-plugins.md) for the upgrade and verification
procedure.

Shortcuts
---------

Every key the configuration binds or overrides — Vim, tmux, Bash, git and
Ghostty — is catalogued in [Shortcuts](.agents/docs/shortcuts.md).

See [chezmoi](https://www.chezmoi.io/).
