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
- `.chezmoi.toml.tmpl`        chezmoi config (sourceDir, merge tool, hooks, `gpg.enabled` flag)
- `.chezmoiignore.tmpl`       files chezmoi should not manage
- `install.sh`                bootstrap chezmoi + apply from a local clone (fresh installs use `readme.md`)
- `bin/executable_swap_ctrl_caps`        → `~/bin/` user script
- `bin/executable_update-passwords`      → `~/bin/update-passwords` `pass` store sync helper; runs `pass git pull --rebase` then `pass git push` against `~/.password-store` (called by the chezmoi post-update hook)
- `bin/executable_git-cleanup`           → `~/bin/git-cleanup` worktree/branch cleanup
- `dot_bashrc` / `dot_profile.tmpl` / `dot_bash_functions`  shell init
- `dot_gitconfig` / `dot_gitignore` / `dot_allowed_signers`  git (SSH signing via `~/.ssh/id_ed25519`)
- `dot_tmux.conf.tmpl`                  tmux config; sources `private_dot_config/tmux/amp-*.conf`
- `symlink_cs.tmpl`, `symlink_icloud.tmpl`, `symlink_notes.tmpl`, `symlink_work-notes.tmpl`  misc targets (notes/work-notes live under `~/Sync/notes/`)
- `run_onchange_install-macos-packages.sh.tmpl`   `brew bundle` (darwin only)
- `run_onchange_install-linux-packages.sh.tmpl`  `dnf`/`flatpak` (linux only); per-host extra block for `black`/`xps13`
- `run_once_after-set-chezmoi-remote-url.sh`
- `run_once_set-up-gpg.sh.tmpl`                   one-time GPG/YubiKey setup (gated on `.gpg.enabled`)
- `run_once_set-up-pass.sh.tmpl`                  one-time `pass` store clone (gated on `.gpg.enabled`; clones the personal store to `~/.password-store`)

`private_dot_config/` → `~/.config` (0700):
- `ghostty/{config.tmpl,themes/}`        Ghostty terminal
- `nvim/{init.lua, ginit.vim.tmpl, symlink_*}`  editor; `lazy-lock.json` is the repo-root pin
- `private_fish/{config.fish.tmpl,functions/}`  fish shell (login shell on macOS and Linux via the install script)
- `tmux/{amp-dark.conf,amp-light.conf}`  tmux theme fragments, sourced by `dot_tmux.conf.tmpl`
- `topgrade.toml.tmpl`                    topgrade
- `opencode/opencode.json`                 base config (`lsp`, `formatter`; no providers/models)
- `opencode/symlink_AGENTS.md.tmpl`        → `~/.config/opencode/AGENTS.md` → `~/.agents/AGENTS.md`
- `opencode.local.json` is machine-local (not tracked); loaded via `OPENCODE_CONFIG` set in fish
  when `~/.config/opencode/opencode.local.json` exists; holds providers, models, mcp, share, agent.title

`private_dot_gnupg/` → `~/.gnupg` (0700): `gpg-agent.conf.tmpl` (OS-gated pinentry)
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

When working in a Git worktree (per global agent instructions), chezmoi's
configured `sourceDir` (`~/code/dotfiles`) points to the main checkout, not
the worktree.  Use `chezmoi --source "$(git rev-parse --show-toplevel)"` to
validate changes against the worktree instead.

1. Start from a clean chezmoi state. Run `chezmoi --source "$(git rev-parse --show-toplevel)" status` first.
2. If not clean, inspect `chezmoi --source "$(git rev-parse --show-toplevel)" diff` and ask the
   user how to proceed (apply, discard, or stash) before making changes.
3. Preview any change before applying with
   `chezmoi --source "$(git rev-parse --show-toplevel)" diff` or
   `chezmoi --source "$(git rev-parse --show-toplevel)" apply --dry-run`.
4. Test templates with
   `chezmoi --source "$(git rev-parse --show-toplevel)" execute-template < file.tmpl`.
5. Apply with `chezmoi --source "$(git rev-parse --show-toplevel)" apply`
   only once the user has confirmed.

Run validation before committing to catch template syntax errors and
unintended changes.

## Boundaries

- Do not push to or pull from the `pass` git store unless asked; the
  post-update hook in `.chezmoi.toml.tmpl` already handles that.
- OS-specific logic is gated on `.chezmoi.os`; the `black` and `xps13`
  hostnames mark Linux desktops via the `desktop.linux` data variable
  (see `.chezmoi.toml.tmpl`).