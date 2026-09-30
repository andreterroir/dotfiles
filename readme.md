Dotfiles & More
===============

Prerequisites
-------------

- curl
- git
- `gh`, logged in as andreterroir: the initial clone uses the credentials
  it stores, and the first apply registers this machine's SSH key

Package install scripts target macOS, Fedora Linux, and headless Ubuntu.
Ubuntu servers get the CLI set only: no fish, hugo, Node, pass, GPG,
YubiKey, or Wayland clipboard tools. Other distros are unsupported.

Install
-------

This repository is private, so the initial clone needs a GitHub login:

    sudo dnf install -y gh git            # brew install gh chezmoi on macOS; apt on Ubuntu
    gh auth login --web --git-protocol https && gh auth setup-git
    sh -c "$(curl -fsLS get.chezmoi.io)" -- init --apply --purge-binary --source=~/code/dotfiles andreterroir

The first apply cannot finish on its own: downloading the YubiKey's
resident SSH key and registering a key on GitHub both need a human at the
keyboard, and chezmoi prints what it skipped. Run it again from a terminal
to finish:

    chezmoi apply

See [chezmoi](https://www.chezmoi.io/).
