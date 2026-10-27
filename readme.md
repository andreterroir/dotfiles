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

Install
-------

    sh -c "$(curl -fsLS get.chezmoi.io)" -- init --apply --purge-binary --source=~/code/dotfiles andreterroir

On physical desktops, the first apply cannot finish on its own: downloading
the YubiKey's resident SSH key, logging in to GitHub, and registering a key
all need a human at the keyboard, and chezmoi prints what it skipped. Run
it again from a terminal to finish:

    chezmoi apply

Virtual machines
----------------

Linux VMs are detected with `systemd-detect-virt --vm` during init. The
`vm` data flag is independent of desktop/server tooling; its value is
preserved on subsequent init runs and can be set in the chezmoi config
on other platforms.

When adopting the provisioning policy or after changing `vm`, run
`chezmoi init` before `chezmoi apply` or `chezmoi update`. Init derives the
`passage` flag as `desktop && !vm` and regenerates the password-update hook.
Do not override `passage` independently: apply rejects missing or
contradictory policy values and asks you to regenerate the configuration.

Both headless servers and VMs have `passage = false`: neither installs
Passage, provisions its identities or store, or runs the password-update
hook. Applying removes old managed password helpers and
plugin references, but never deletes an existing store or local identities.
This is a provisioning policy, not a sandbox against manually granted access.

Interactive Git signing uses an approved YubiKey key if available in the
agent, otherwise the VM's machine key. Unattended signing uses the machine
key. VM machine keys are generated without a passphrase and registered for
GitHub signing and authentication; they are not authorized on the password
server. GitHub registration still requires a terminal and account login.

YubiKeys remain optional: forward an agent containing an approved resident
key, or download it explicitly with `ssh-keygen -K` and save the key pair as
`~/.ssh/id_ed25519_sk` and `~/.ssh/id_ed25519_sk.pub`, then load it with
`ssh-add ~/.ssh/id_ed25519_sk`. VM setup never downloads a resident key.
Public-only references in `~/.ssh/identities/` allow forwarded approved
keys through SSH's identity filter without requiring local resident keys.

Validation: `python3 -m unittest discover -s tests` (chezmoi and OpenSSH required).

See [chezmoi](https://www.chezmoi.io/).
