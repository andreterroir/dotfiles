Dotfiles & More
===============

Prerequisites
-------------

- curl
- git

Package install scripts target macOS, Fedora Linux, and headless Ubuntu.
Ubuntu servers get the CLI set only: no hugo, Node, YubiKey, or
Wayland clipboard tools. Other distros are unsupported.

Install
-------

    sh -c "$(curl -fsLS get.chezmoi.io)" -- init --apply --purge-binary --source=~/code/dotfiles andreterroir

The first apply cannot finish on its own: downloading the YubiKey's
resident SSH key, logging in to GitHub, and registering a key all need a
human at the keyboard, and chezmoi prints what it skipped. Run it again
from a terminal to finish:

    chezmoi apply

See [chezmoi](https://www.chezmoi.io/).
