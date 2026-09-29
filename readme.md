Dotfiles & More
===============

Prerequisites
-------------

- curl
- git
- `ykman` and `yubico-piv-tool`, for the YubiKey identity the initial
  clone authenticates with (see [YubiKey PIV](.agents/docs/yubikey-piv.md))

Package install scripts target macOS, Fedora Linux, and headless Ubuntu.
Ubuntu servers get the CLI set only: no fish, hugo, Node, pass, GPG,
YubiKey, or Wayland clipboard tools. Other distros are unsupported.

Install
-------

This repository is private, so the initial clone needs an SSH identity.
The YubiKey PIV key supplies it, so a machine needs no key of its own
beforehand — but `ssh` only reaches the key when told about the PKCS#11
module, which `GIT_SSH_COMMAND` passes through to the clone:

    mkdir -p ~/code && GIT_SSH_COMMAND="ssh -o PKCS11Provider=/usr/lib64/libykcs11.so.2" \
        sh -c "$(curl -fsLS get.chezmoi.io)" -- init --apply --ssh --purge-binary --source=~/code/dotfiles andreterroir

On macOS the provider is `/opt/homebrew/lib/libykcs11.dylib`. The
bootstrap then registers a per-machine ed25519 key, which is preferred
from then on and needs no provider.

See [chezmoi](https://www.chezmoi.io/).

YubiKey PIV
-----------

The slot-9a key is the SSH identity used before a machine has a key of
its own, and a fallback afterwards. It is set up once per YubiKey;
setup, usage and the GnuPG reader-sharing fix are documented in
[YubiKey PIV](.agents/docs/yubikey-piv.md).
