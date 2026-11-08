# Dotfiles (chezmoi)

This repo manages user dotfiles with [chezmoi](https://www.chezmoi.io/).
Source files live in `~/code/dotfiles` and are applied to `$HOME`.
Commit-message conventions live in `dot_agents/AGENTS.md` and are
installed globally; do not duplicate them here.

## Where agent instructions live

- `dot_agents/AGENTS.md` — user-global instructions (code review, commit
  conventions, etc.), deployed by chezmoi to
  `~/.agents/AGENTS.md` and symlinked from `dot_claude/`,
  `dot_codex/`, `dot_copilot/`, `private_dot_config/opencode/`, and
  `private_dot_config/` (as `~/.config/AGENTS.md` for Amp). Edit there,
  not here.
- `~/.config/amp/AGENTS.md` is not managed by chezmoi. Amp reads it
  alongside `~/.config/AGENTS.md`, so instructions that platforms such
  as an orb write there survive applies instead of being replaced. A
  one-time script retires the symlink earlier applies left there.
- `AGENTS.md` (this file) — repo-level instructions only, for anything
  specific to *editing this repository* (chezmoi workflow, file
  conventions, boundaries).

## Repository layout

See the source tree for the current layout and [readme.md](readme.md) for
supported platforms and installation. See
[Vim plugins](.agents/docs/vim-plugins.md) before changing
`plug-snapshot.vim` or the plugin list, and
[Vim migration](.agents/docs/vim-migration.md) for what the move from
Neovim changed and which capabilities it dropped.

`run_*` scripts fire in alphabetical order of their target names, so
`run_onchange_install-*-packages` runs before
`run_onchange_set-up-default-shell` (which runs `chsh`). Scripts with a
`run_after_` prefix run after all of those, whatever their name, so a
script that needs a tool the package script installs belongs there.
Fedora and Ubuntu use the distro Bash, which is already present. Keep this
ordering in mind when adding `run_*` scripts whose preconditions are
installed by another script.

## File conventions

- `dot_*`            → `~/.<name>` (e.g. `dot_gitconfig.tmpl` → `~/.gitconfig`)
- `private_*`        → target with restricted (`0700`) permissions
- `*.tmpl`           → chezmoi templates; use `{{ }}` and the role data
                       variables (`desktop`, `server`, `vm`, `keepass`)
- `run_onchange_*`   → scripts re-run when their checksum changes
- `run_once_*`       → scripts run at most once
- `symlink_*`        → emit a symlink whose target is the file's contents
- `executable_*`     → emitted with the executable bit set
- `.chezmoiignore.tmpl` / `.chezmoi.toml.tmpl` → chezmoi config; edit deliberately
- `.chezmoiremove`   → glob patterns (relative to `$HOME`) for targets
                       chezmoi removes on every apply; retires files
                       dropped from the source tree and state left over
                       from retired tools

## Shortcuts

Every key the configuration binds is catalogued in
[Shortcuts](.agents/docs/shortcuts.md). Any change that adds, removes or
rebinds a key updates that document in the same change: the maps and plugin
globals in `dot_vimrc`, the bindings in `dot_tmux.conf.tmpl`, the readline and
fzf keys in `dot_bashrc`, the git aliases and mergetool, and the Ghostty
keybinds. Record a deliberate removal under the section that lists dropped
keys, with its reason, so the key is not reintroduced by accident.

## Workflow

The default installation uses `~/code/dotfiles` as chezmoi's `sourceDir`.
Initializing with `--source` pointing to a worktree persists that path
instead. When the checkout is a linked worktree, use
`chezmoi --source "$(git rev-parse --show-toplevel)"` to validate that
worktree regardless of the configured source.

0. Rebase onto main if the worktree branch is behind.
1. Start from a clean chezmoi state. Run `chezmoi --source "$(git rev-parse --show-toplevel)" status` first.
2. Ignore pending scripts that always run (`run_*` without `once_` or
   `onchange_`), which appear on every status check. If any other changes
   remain, inspect `chezmoi --source "$(git rev-parse --show-toplevel)" diff`
   and ask the user how to proceed (apply, discard, or stash) before making
   changes. Pending once/onchange scripts still require this decision.
3. Preview any change before applying with
   `chezmoi --source "$(git rev-parse --show-toplevel)" diff` or
   `chezmoi --source "$(git rev-parse --show-toplevel)" apply --dry-run`.
4. Test templates with
   `chezmoi --source "$(git rev-parse --show-toplevel)" execute-template < file.tmpl`.
5. Apply with `chezmoi --source "$(git rev-parse --show-toplevel)" apply`
   only once the user has confirmed.

Run validation before committing to catch template syntax errors and
unintended changes. Do a fast forward only merge when asked to integrate the changes into main branch.

## Shipping

Treat a request to ship (or to integrate into `main`) as confirmation to apply:
fast-forward `main`, push, then apply from the main checkout and report what
changed. Apply from the main checkout, not from a linked worktree, so symlinks
keep pointing at `~/code/dotfiles`.

## Machines

Every hostname this repository names, whether a `chezmoi.hostname` that
templates gate on or an SSH destination. Role is derived at bootstrap from
the machine itself (`gnome-shell` on PATH, `systemd-detect-virt`), not from
the hostname, and describes only the machines chezmoi manages (see
Boundaries).

| Hostname | OS | Role | Notes |
| --- | --- | --- | --- |
| x1 | Fedora Linux | desktop | the workstation laptop; the YubiKey 5C Nano stays in it, and its machine key is the only general authentication fallback |
| black | Fedora Linux | desktop | the desktop workstation |
| slate-vm-work | Fedora Linux | desktop, vm | VM without password-manager apps; YubiKey optional |
| greenhouse | Ubuntu Linux | server | headless Amp runner; planned for decommissioning; older commits call it `netcup` |
| chalon | Raspberry Pi OS Lite | server | a Tailscale VPN gateway; an SSH destination, not a chezmoi target |
| git.terroir.systems | unrecorded | server | an externally managed host; an SSH destination, not a chezmoi target |

`github.com` is a service, not a machine. `xps13` appears in older commits
but is retired: a hostname found in the history is not evidence that the
machine still exists. `slate` and `Chloes-MBP` were macOS chezmoi targets and
are no longer managed: the repository supports Linux only.

## Boundaries

- Gate tooling on role data, not hostnames; `vm` is independent of role.
  See [Provisioning model](.agents/docs/provisioning.md) for detection,
  authentication exceptions, and sudo policy; see
  [Commit signing](.agents/docs/signing.md) for signing and agents.
- VM machine keys are GitHub authentication fallbacks only. Preserve
  explicit repository signing overrides without silent fallback.
- Linux only: `.chezmoi.toml.tmpl` and `.chezmoiignore.tmpl` fail on any
  other platform, so templates and `run_*` scripts may assume Linux. Do not
  reintroduce `eq .chezmoi.os "linux"` guards; put new platform support
  behind that fail instead.
- In `run_*` scripts, use `$CHEZMOI_SOURCE_DIR` (set by chezmoi when
  running scripts) rather than `chezmoi source-path`: a nested
  `chezmoi` invocation deadlocks on the parent `chezmoi apply`'s
  persistent-state lock.
