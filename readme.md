Dotfiles & More
===============

Prerequisites
-------------

- curl
- git

Install
-------

    mkdir -p ~/code && sh -c "$(curl -fsLS get.chezmoi.io)" -- init --apply --ssh --purge-binary --source=~/code/dotfiles andreterroir

See [chezmoi](https://www.chezmoi.io/).

YubiKey PIV (first time, per YubiKey)
------------------------------------

Done once per YubiKey, before applying this repo to any machine.

Install `ykman` and `yubico-piv-tool` (e.g. `brew install ykman
yubico-piv-tool` on macOS, `sudo dnf install yubikey-manager
yubico-piv-tool` on Fedora). Plug in the YubiKey, then:

1. Set the PIV PIN (default is `123456`):

       ykman piv access change-pin

2. Generate an ECC P-256 key in slot 9c with once-per-session PIN and
   cached touch. (PIV Ed25519 requires YubiKey firmware 5.7+; ECC P-256
   is supported on every YubiKey 5/4/Neo.)

       ykman piv keys generate --algorithm ECCP256 \
           --pin-policy=once --touch-policy=cached 9c /tmp/piv-pub.pem

3. Self-sign a certificate in slot 9c:

       ykman piv certificates generate \
           --subject "CN=andre@terroir.systems (yubikey-piv)" 9c /tmp/piv-pub.pem

   The `/tmp/piv-pub.pem` file is the public key in PEM form; you can
   delete it after step 4.

4. Extract the PIV public key in SSH form and register it on both
   endpoints as a permanent fallback identity:

       ykman piv certificates export 9c - \
           | openssl x509 -pubkey -noout \
           | ssh-keygen -i -m PKCS8 -f /dev/stdin \
           > ~/.ssh/id_yubikey_piv.pub
       chmod 644 ~/.ssh/id_yubikey_piv.pub

   The PIV cert's private key is on the YubiKey, not on disk, so use
   `-f` with ssh-copy-id to skip the on-disk private-key lookup:

       ssh-copy-id -f -i ~/.ssh/id_yubikey_piv.pub REDACTED
       gh ssh-key add ~/.ssh/id_yubikey_piv.pub --title "yubikey-piv"
