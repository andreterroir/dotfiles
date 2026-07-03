# Dotfiles (chezmoi)

This repo manages user dotfiles with [chezmoi](https://www.chezmoi.io/).
Source files live in `~/code/dotfiles` and are applied to `$HOME`.
Commit-message conventions live in `dot_agents/AGENTS.md` and are
installed globally; do not duplicate them here.

## Where agent instructions live

- `AGENTS.md` (this file) — repo-level instructions for working in this
  dotfiles repo. Add anything specific to *editing this repository* here.
- `dot_agents/AGENTS.md` — user-global instructions, deployed by chezmoi
  to `~/.agents/AGENTS.md`, and symlinked from `dot_claude/` and
  `private_dot_config/opencode/` into Claude and opencode configs. Move
  global guidance there, not here.

## Repository layout

Top level (each `dot_*` maps to `~/.<name>`):
- `.chezmoi.toml.tmpl`        chezmoi config (sourceDir, merge tool, hooks, `gpg.enabled`, `work.laptop` flags)
- `.chezmoiignore.tmpl`       files chezmoi should not manage
- `install.sh`                bootstrap chezmoi + apply from a local clone (fresh installs use `readme.md`)
- `update-passwords.sh`       `pass` store helper
- `bin/executable_swap_ctrl_caps`        → `~/.bin/` user script
- `dot_bashrc.tmpl` / `dot_profile.tmpl` / `dot_bash_functions`  shell init
- `dot_gitconfig.tmpl` / `dot_gitignore` / `dot_allowed_signers`  git (SSH signing via `~/.ssh/id_ed25519`)
- `dot_tmux.conf.tmpl`                  tmux config; sources `private_dot_config/tmux/amp-*.conf`
- `symlink_cs.tmpl`, `symlink_icloud.tmpl`  misc targets
- `run_onchange_install-macos-packages.sh.tmpl`   `brew bundle` (darwin only)
- `run_onchange_install-linux-packages.sh.tmpl`  `dnf`/`flatpak` (linux only); per-host extra block for `black`/`xps13`
- `run_once_after-set-chezmoi-remote-url.sh.tmpl`

`private_dot_config/` → `~/.config` (0700):
- `ghostty/{config.tmpl,themes/}`        Ghostty terminal
- `nvim/{init.lua, ginit.vim.tmpl, symlink_*}`  editor; `lazy-lock.json` is the repo-root pin
- `private_fish/{config.fish.tmpl,functions/}`  fish shell (login shell on macOS and Linux via the install script)
- `tmux/{amp-dark.conf,amp-light.conf}`  tmux theme fragments, sourced by `dot_tmux.conf.tmpl`
- `topgrade.toml.tmpl`                    topgrade
- `opencode/symlink_AGENTS.md.tmpl`        → `~/.config/opencode/AGENTS.md` → `~/.agents/AGENTS.md`

`private_dot_gnupg/` → `~/.gnupg` (0700): `gpg-agent.conf.tmpl`
`private_dot_ssh/private_config.tmpl` → `~/.ssh/config` (0700)

## File conventions

- `dot_*`            → `~/.<name>` (e.g. `dot_gitconfig.tmpl` → `~/.gitconfig`)
- `private_*`        → target with restricted (`0700`) permissions
- `*.tmpl`           → chezmoi templates; use `{{ }}`, gate on
                       `.chezmoi.os` ("linux"/"darwin") and `.chezmoi.hostname`
- `run_onchange_*`   → scripts re-run when their checksum changes
- `run_once_*`       → scripts run at most once
- `symlink_*`        → emit a symlink whose target is the file's contents
- `executable_*`     → emitted with the executable bit set
- `.chezmoiignore.tmpl` / `.chezmoi.toml.tmpl` → chezmoi config; edit deliberately

## Workflow

1. Start from a clean chezmoi state. Run `chezmoi status` first.
2. If `chezmoi status` is not clean, inspect `chezmoi diff` and ask the
   user how to proceed (apply, discard, or stash) before making changes.
3. Preview any change before applying with `chezmoi diff` or
   `chezmoi apply --dry-run` against `$HOME`.
4. Test templates with `chezmoi execute-template < file.tmpl`.
5. Apply with `chezmoi apply` only once the user has confirmed.

## Boundaries

- Do not push to or pull from the `pass` git store unless asked; the
  post-update hook in `.chezmoi.toml.tmpl` already handles that.
- OS-specific logic is gated on `.chezmoi.os`; the `slate` hostname marks
  the work laptop (see `.chezmoi.toml.tmpl`).