# Dotfiles (chezmoi)

This repo manages user dotfiles with [chezmoi](https://www.chezmoi.io/).
Source files live in `~/code/dotfiles` and are applied to `$HOME`.
Commit-message conventions live in `dot_agents/AGENTS.md` and are
installed globally; do not duplicate them here.

## Where agent instructions live

- `dot_agents/AGENTS.md` — user-global instructions (worktree workflow,
  code review, commit conventions, etc.), deployed by chezmoi to
  `~/.agents/AGENTS.md` and symlinked from `dot_claude/`,
  `dot_codex/`, `dot_copilot/`, `private_dot_config/opencode/`, and
  `private_dot_config/private_amp/`. Edit there, not here.
- `AGENTS.md` (this file) — repo-level instructions only, for anything
  specific to *editing this repository* (chezmoi workflow, file
  conventions, boundaries).

## Repository layout

See the source tree for the current layout. Package install scripts target
macOS, Fedora Linux, and headless Ubuntu. Ubuntu servers get the CLI set
only: no hugo, Node, YubiKey, or Wayland clipboard tools.
Other distros are unsupported.

`run_*` scripts fire in alphabetical order of their target names, so
`run_onchange_install-*-packages` runs before
`run_onchange_set-up-default-shell` (which runs `chsh`). Scripts with a
`run_after_` prefix run after all of those, whatever their name, so a
script that needs a tool the package script installs belongs there. On
macOS the install script provides Homebrew Bash; Fedora and Ubuntu use
the distro Bash, which is already present. Keep this ordering in
mind when adding `run_*` scripts whose preconditions are installed
by another script.

## File conventions

- `dot_*`            → `~/.<name>` (e.g. `dot_gitconfig.tmpl` → `~/.gitconfig`)
- `private_*`        → target with restricted (`0700`) permissions
- `*.tmpl`           → chezmoi templates; use `{{ }}`, gate on
                       `.chezmoi.os` ("linux"/"darwin") and the role data
                       variables (`desktop`, `linux.desktop`, `server`, `vm`, `passage`)
- `run_onchange_*`   → scripts re-run when their checksum changes
- `run_once_*`       → scripts run at most once
- `symlink_*`        → emit a symlink whose target is the file's contents
- `executable_*`     → emitted with the executable bit set
- `.chezmoiignore.tmpl` / `.chezmoi.toml.tmpl` → chezmoi config; edit deliberately
- `.chezmoiremove`   → glob patterns (relative to `$HOME`) for targets
                       chezmoi removes on every apply; retires files
                       dropped from the source tree and state left over
                       from retired tools

## Workflow

The default installation uses `~/code/dotfiles` as chezmoi's `sourceDir`.
Initializing with `--source` pointing to a worktree persists that path
instead. When working in a Git worktree (per global agent instructions),
use `chezmoi --source "$(git rev-parse --show-toplevel)"` to validate the
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
the OS, not from the hostname, and describes only the machines chezmoi
manages (see Boundaries).

| Hostname | OS | Role | Notes |
| --- | --- | --- | --- |
| slate | macOS | desktop | the only work machine; its machine-local age identity decrypts only the store's `work/*` subtree |
| x1 | Fedora Linux | desktop | the workstation laptop; the YubiKey 5C Nano stays in it, and its machine key is the only general authentication fallback |
| black | Fedora Linux | desktop | the desktop workstation |
| Chloes-MBP | macOS | desktop | a laptop |
| slate-vm-work | Fedora Linux | desktop, vm | VM with no provisioned password-store access; YubiKey optional |
| greenhouse | Ubuntu Linux | server | headless Amp runner; planned for decommissioning; older commits call it `netcup` |
| chalon | Raspberry Pi OS Lite | server | a Tailscale VPN gateway; an SSH destination, not a chezmoi target |
| git.terroir.systems | unrecorded | server | an externally managed host serving the Passage store; an SSH destination, not a chezmoi target |

`github.com` is a service, not a machine. `xps13` appears in older commits
but is retired: a hostname found in the history is not evidence that the
machine still exists.

## Boundaries

- Do not push to or pull from the Passage git store unless asked; the
  post-update hook in `.chezmoi.toml.tmpl` already handles that.
- Machine role comes from the `desktop` data variable, which bootstrap
  derives without prompting: it is true on macOS and on Linux hosts with
  `gnome-shell` on PATH. Every host that is not a desktop is a headless
  machine reached over SSH via the `server` data variable, and
  `linux.desktop` marks Linux desktops (see `.chezmoi.toml.tmpl`).
  `vm` is independent of that role: Linux init detects virtual machines
  with `systemd-detect-virt --vm`, preserving an existing configured value.
  `passage` is strictly derived at init as `desktop && !vm`; use that flag
  for all Passage provisioning and synchronization, not role checks.
  Run `chezmoi init` before apply/update when adopting the policy or
  changing `vm`; missing or contradictory policy data fails closed.
  VMs never provision Passage. All machines sign commits with their local
  SSH key by default; repository configuration may opt into YubiKey signing.
  VM machine keys are GitHub authentication fallbacks only, not
  password-server keys.
  `.chezmoi.osRelease` is empty off Linux. Nest a distro check inside
  `eq .chezmoi.os "linux"`; `text/template` evaluates both sides of
  `and`, so a combined condition still looks up the missing `id` key.
- In `run_*` scripts, use `$CHEZMOI_SOURCE_DIR` (set by chezmoi when
  running scripts) rather than `chezmoi source-path`: a nested
  `chezmoi` invocation deadlocks on the parent `chezmoi apply`'s
  persistent-state lock.
