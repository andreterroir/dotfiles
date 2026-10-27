Dotfiles & More
===============

Prerequisites
-------------

- curl
- git

Package install scripts target macOS, Fedora Linux, and headless Ubuntu.
Ubuntu servers get the CLI set only: no hugo, Node, YubiKey, or
Wayland clipboard tools. Other distros are unsupported.
Fedora desktops skip Spotify on ARM because its Flathub package is x86_64-only.
Chezmoi downloads the two configured Ghostty themes from a pinned upstream
revision because Terra's Ghostty package omits bundled themes.

Install
-------

    sh -c "$(curl -fsLS get.chezmoi.io)" -- init --apply --purge-binary --source=~/code/dotfiles andreterroir

On physical desktops, the first apply cannot finish on its own: downloading
the YubiKey's resident SSH key, logging in to GitHub, and registering a key
all need a human at the keyboard, and chezmoi prints what it skipped. Run
it again from a terminal to finish:

    chezmoi apply

Git commit signing
------------------

Commits use the machine-local SSH key by default. See
[Commit signing](.agents/docs/signing.md) for repository-level YubiKey
overrides, agent setup, verification, and troubleshooting.

Provisioning
------------

Desktop/server role selects tooling; VMs keep that tooling but do not
provision Passage. See the [Provisioning model](.agents/docs/provisioning.md)
for role detection, VM configuration, credentials, sudo, and background
services. After changing `vm`, run `chezmoi init` before apply or update.

See [chezmoi](https://www.chezmoi.io/).
