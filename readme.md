Dotfiles & More
===============

Prerequisites
-------------

- curl
- git

This repo targets macOS and Fedora Linux. Other distros are
unsupported; the install scripts use `brew` and `dnf`/`flatpak`.

Install
-------

    mkdir -p ~/code && sh -c "$(curl -fsLS get.chezmoi.io)" -- init --apply --ssh --purge-binary --source=~/code/dotfiles andreterroir

See [chezmoi](https://www.chezmoi.io/).

YubiKey PIV (once per YubiKey)
------------------------------

Done once per YubiKey, before applying this repo to any machine. The
slot-9a key created here is a permanent fallback identity used by the
SSH config's `PKCS11Provider`; the per-machine ed25519 from
`run_once_set-up-3-ssh.sh.tmpl` remains the primary identity.

Based on the
[Yubico guide](https://developers.yubico.com/PIV/Guides/SSH_with_PIV_and_PKCS11.html).
Install `ykman` and `yubico-piv-tool` if missing (`brew install ykman
yubico-piv-tool` on macOS, `sudo dnf install yubikey-manager
yubico-piv-tool` on Fedora). Plug in the YubiKey, then:

1. Set the PIV PIN (default is `123456`):

       ykman piv access change-pin

2. Generate an ECC P-256 key in slot 9a (prompts for the management
   key):

       yubico-piv-tool --key --algorithm=ECCP256 --slot=9a \
           --action=generate --output=/tmp/public.pem

3. Self-sign a certificate in slot 9a (prompts for the PIV PIN) and
   load it back into the slot:

       yubico-piv-tool --key \
           --action=verify-pin --action=selfsign-certificate \
           --slot=9a --subject="/CN=andre@terroir.systems/" \
           --input=/tmp/public.pem --output=/tmp/cert.pem
       yubico-piv-tool --key --action=import-certificate \
           --slot=9a --input=/tmp/cert.pem
       rm /tmp/public.pem /tmp/cert.pem

4. Export the PIV public key in SSH format. The grep filters out the
   9c (signature) and 9e (attestation) keys the libykcs11 module
   also surfaces, leaving just the 9a "PIV Authentication" line:

       ssh-keygen -D /opt/homebrew/lib/libykcs11.dylib \
           | grep 'PIV Authentication' > /tmp/piv.pub          # macOS
       # Linux: replace the path with /usr/lib64/libykcs11.so
       cat /tmp/piv.pub

   Should print one line of the form
   `ecdsa-sha2-nistp256 AAAA...== Public key for PIV Authentication`.

5. Register the PIV public key on netcup and GitHub. `-f` skips the
   launchd-ssh-agent quirk in `ssh-copy-id`'s "is this key already
   installed?" probe:

       ssh-copy-id -f -i /tmp/piv.pub REDACTED
       gh ssh-key add /tmp/piv.pub --title "yubikey-piv"
       rm /tmp/piv.pub

The SSH config's `PKCS11Provider` for `github.com` and
`REDACTED` makes ssh use libykcs11 directly for those hosts,
so no ssh-agent setup is required for them. (Optional) To also
expose the key via ssh-agent for other uses, run
`ssh-add -s <libykcs11>` and confirm with `ssh-add -l` — but note
that macOS launchd-ssh-agent (the default `SSH_AUTH_SOCK` on macOS)
does not support PKCS#11 cards. To use ssh-add -s on macOS, start
OpenSSH's ssh-agent manually: `eval $(ssh-agent)` and re-export
`SSH_AUTH_SOCK` before adding the card.
