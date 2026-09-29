Dotfiles & More
===============

Prerequisites
-------------

- curl
- git

Package install scripts target macOS, Fedora Linux, and headless Ubuntu.
Ubuntu servers get the CLI set only: no fish, hugo, Node, pass, GPG,
YubiKey, or Wayland clipboard tools. Other distros are unsupported.

Install
-------

    mkdir -p ~/code && sh -c "$(curl -fsLS get.chezmoi.io)" -- init --apply --ssh --purge-binary --source=~/code/dotfiles andreterroir

See [chezmoi](https://www.chezmoi.io/).

YubiKey PIV
-----------

The slot-9a key is the SSH identity used before a machine has a key of
its own, and a fallback afterwards. It is set up once per YubiKey;
setup, usage and the GnuPG reader-sharing fix are documented in
[YubiKey PIV](.agents/docs/yubikey-piv.md).
