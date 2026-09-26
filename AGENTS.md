# Dotfiles (chezmoi)

This repo manages user dotfiles with [chezmoi](https://www.chezmoi.io/).
Source files live in `~/code/dotfiles` and are applied to `$HOME`.
Commit-message conventions live in `dot_agents/AGENTS.md` and are
installed globally; do not duplicate them here.

## Where agent instructions live

- `dot_agents/AGENTS.md` — user-global instructions (worktree workflow,
  code review, commit conventions, etc.), deployed by chezmoi to
  `~/.agents/AGENTS.md` and symlinked from `dot_claude/` and
  `private_dot_config/opencode/`. Edit there, not here.
- `AGENTS.md` (this file) — repo-level instructions only, for anything
  specific to *editing this repository* (chezmoi workflow, file
  conventions, boundaries).

## Repository layout

See the source tree for the current layout. Package install scripts target
macOS, Fedora Linux, and headless Ubuntu. Ubuntu servers get the CLI set
only: no fish, hugo, Node, pass, GPG, YubiKey, or Wayland clipboard tools.
Other distros are unsupported.

`run_*` scripts fire in alphabetical order of their target names, so
`run_onchange_install-*-packages` runs before
`run_onchange_set-up-default-shell` (which runs `chsh`). On macOS
the install script provides Homebrew Bash; Fedora and Ubuntu use
the distro Bash, which is already present. Keep this ordering in
mind when adding `run_*` scripts whose preconditions are installed
by another script.

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

0. Rebase onto main if the worktree branch is behind.
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
unintended changes. Do a fast forward only merge when asked to integrate the changes into main branch.

## Boundaries

- Do not push to or pull from the `pass` git store unless asked; the
  post-update hook in `.chezmoi.toml.tmpl` already handles that.
- OS-specific logic is gated on `.chezmoi.os`; the `black` and `x1`
  hostnames mark Linux desktops via the `linux.desktop` data variable,
  and every other host is a headless machine reached over SSH via the
  `server` data variable (see `.chezmoi.toml.tmpl`).
- In `run_*` scripts, use `$CHEZMOI_SOURCE_DIR` (set by chezmoi when
  running scripts) rather than `chezmoi source-path`: a nested
  `chezmoi` invocation deadlocks on the parent `chezmoi apply`'s
  persistent-state lock.
