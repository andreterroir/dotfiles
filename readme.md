Dotfiles & More
===============

Prerequisites
-------------

- curl
- git

This repository provisions Fedora desktops, their VMs, and one headless Ubuntu
dev server. Containers, Amp orbs, and unlisted hosts get a portable set-up with
no packages and no identity, and a host that is not Linux gets those same
portable files. See the [Provisioning model](.agents/docs/provisioning.md) for
the exact scope.

Install
-------

    sh -c "$(curl -fsLS get.chezmoi.io)" -- init --apply --purge-binary --source=~/code/dotfiles andreterroir

This is for managed machines; add a new physical machine to `managedHosts`
(`.chezmoidata.toml`) before its full install. Elsewhere, `./install.sh` from a
clone of this repository applies the portable set-up: a container, an orb, or
an unlisted host gets Vim and agent instructions, with no packages, and keeps
its own shell, Git, and tmux configuration.

A machine's identity set-up needs a human at the keyboard when it has work to
do: creating a passphrase-protected key or logging in to GitHub. An apply
without a terminal cannot do that, so chezmoi reports the identity script as
failed rather than skipping it, and applying again from a terminal finishes it:

    chezmoi apply

That script and the signing allowlist run once; see
[One-shot set-up scripts](.agents/docs/provisioning.md#one-shot-set-up-scripts)
to run them again.

Documentation
-------------

- [Provisioning model](.agents/docs/provisioning.md): profile data, set-ups,
  identity, sudo, packages, extensions, and services.
- [Commit signing](.agents/docs/signing.md): agents, verification, failures.
- [Vim plugins](.agents/docs/vim-plugins.md): pins, upgrading, verification.
- [Shortcuts](.agents/docs/shortcuts.md): every key bound or overridden.
- [Fedora upgrades](.agents/docs/upgrades.md): the in-place release upgrade.

See [chezmoi](https://www.chezmoi.io/).
