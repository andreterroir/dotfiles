YubiKey PIV
===========

The YubiKey's PIV applet holds an ECC P-256 key in slot 9a that
authenticates SSH connections. It is the only SSH identity a machine has
before this repository has been applied to it, so it is what makes the
initial clone of this private repository possible, and it stays as a
fallback afterwards.

Set this up once per YubiKey, before applying this repository to any
machine. Based on the
[Yubico guide](https://developers.yubico.com/PIV/Guides/SSH_with_PIV_and_PKCS11.html).

Setup
-----

Install `ykman` and `yubico-piv-tool` if missing (`brew install ykman
yubico-piv-tool` on macOS, `sudo dnf install yubikey-manager
yubico-piv-tool` on Fedora). Plug in the YubiKey, then:

1. Replace the factory credentials: PIN `123456`, PUK `12345678` and
   management key `010203040506070801020304050607080102030405060708`.
   The PIN protects use of the slot-9a key and the PUK unblocks a
   blocked PIN, so leaving either at its factory value lets anyone who
   can hold the device take the key over. `--generate` prints a random
   management key that has to be recorded (e.g. in `pass`); the later
   steps prompt for it:

       ykman piv access change-pin
       ykman piv access change-puk
       ykman piv access change-management-key --generate

2. Generate an ECC P-256 key in slot 9a (prompts for the management
   key):

       yubico-piv-tool --key --algorithm=ECCP256 --slot=9a \
           --action=generate --output=/tmp/public.pem

3. Self-sign a certificate in slot 9a (prompts for the PIV PIN) and
   load it back into the slot. libykcs11 only surfaces a slot once it
   holds a certificate, so this is what makes the key visible to `ssh`:

       yubico-piv-tool --key \
           --action=verify-pin --action=selfsign-certificate \
           --slot=9a --subject="/CN=andre@terroir.systems/" \
           --input=/tmp/public.pem --output=/tmp/cert.pem
       yubico-piv-tool --key --action=import-certificate \
           --slot=9a --input=/tmp/cert.pem
       rm /tmp/public.pem /tmp/cert.pem

4. Export the PIV public key in SSH format. libykcs11 also lists the 9c
   (signature) and f9 (attestation) keys, so the grep keeps just the 9a
   "PIV Authentication" line:

       ssh-keygen -D /opt/homebrew/lib/libykcs11.dylib \
           | grep 'PIV Authentication' > /tmp/piv.pub          # macOS
       # Linux: replace the path with /usr/lib64/libykcs11.so.2
       cat /tmp/piv.pub

   Should print one line of the form
   `ecdsa-sha2-nistp256 AAAA...== Public key for PIV Authentication`.

5. Register the PIV public key on netcup and GitHub. `-f` skips the
   launchd-ssh-agent quirk in `ssh-copy-id`'s "is this key already
   installed?" probe:

       ssh-copy-id -f -i /tmp/piv.pub REDACTED
       gh ssh-key add /tmp/piv.pub --title "yubikey-5-piv"
       rm /tmp/piv.pub

   The title names the model, so a YubiKey 4 gets `yubikey-4-piv`.

Using it
--------

`ssh` only reaches the key when it is told about the PKCS#11 module, so
the provider is passed per invocation:

    ssh -o PKCS11Provider=/usr/lib64/libykcs11.so.2 REDACTED

It is deliberately not in `~/.ssh/config`. A `PKCS11Provider` there
disables `UseKeychain` on macOS, so the ed25519 passphrase would have to
be re-entered after every reboot, and it makes libykcs11 write to stderr
on every connection to those hosts while it enumerates private keys
without a login (`pin required`, `C_FindObjectsInit failed: 179`).

Two scripts use it inline instead:

- the install command in `readme.md`, via `GIT_SSH_COMMAND`, so the
  initial clone works on a machine with no key of its own;
- `run_once_set-up-3-ssh.sh.tmpl`, which registers a per-machine ed25519
  key on netcup and GitHub.

After that the ed25519 key is offered first and PIV is only a fallback,
so the PIN is normally never needed.

Sharing the YubiKey with GnuPG
------------------------------

The same YubiKey also carries the OpenPGP applet used by GnuPG and
`pass`, and by default the two fight over it. `scdaemon` drives the CCID
reader itself and takes it exclusively, so while it holds the device
`ykman` fails with "Failed opening device"; while `pcscd` holds it,
`gpg --card-status` fails with "No such device". Even once `scdaemon` is
routed through pcscd it still connects in shared-incompatible mode,
because GnuPG defaults to exclusive PC/SC access:

    pcsc_connect failed: sharing violation (0x8010000b)

`private_dot_gnupg/scdaemon.conf` settles it:

    disable-ccid      # route scdaemon through pcscd instead of the USB device
    pcsc-shared       # connect in shared mode (GnuPG >= 2.2.28)
    card-timeout 5    # release the card when idle

Caveats
-------

- A slot is invisible to libykcs11 until it holds a certificate, which is
  why step 3 is not optional. A key in 9c without a certificate will
  never show up.
- The PIN is required once per card session, so it is prompted for once
  per `ssh` invocation unless another PC/SC client has already logged in.
- `ykman piv info` reports the credentials that are still at their
  factory values, and the management key algorithm. If it cannot connect,
  another PC/SC client is holding the reader.
