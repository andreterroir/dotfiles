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
