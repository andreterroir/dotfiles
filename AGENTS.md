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
  `private_dot_config/` (as `~/.config/AGENTS.md` for Amp). The opencode
  link is Linux-only, like opencode. Edit there, not here.
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
`plug-snapshot.vim` or the plugin list.

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
- `*.tmpl`           → chezmoi templates; use `{{ }}`, gate on
                       `.chezmoi.os` ("linux"/"darwin") and the role data
                       variables (`desktop`, `linux.desktop`, `server`, `vm`,
                       `transient`); derive `desktop && !vm` for KeePass
                       gating
- `run_onchange_*`   → scripts re-run when their checksum changes
- `run_once_*`       → scripts run at most once
- `symlink_*`        → emit a symlink whose target is the file's contents
- `executable_*`     → emitted with the executable bit set
- `.chezmoiignore.tmpl` / `.chezmoi.toml.tmpl` → chezmoi config; edit deliberately
- `.chezmoiremove`   → when present, glob patterns (relative to `$HOME`)
                       for targets chezmoi removes on every apply; used
                       transiently to retire files dropped from the
                       source tree and state left over from retired tools

## Shortcuts

Every key the configuration binds or overrides is catalogued in
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

A transient environment — a container, or a hostname outside
`managedHosts` — runs `./install.sh --transient`; see
[Transient profile](.agents/docs/transient.md) for detection. Amp
orbs are not targets at all: the set-up refuses to run inside one.

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

The full apply is for managed machines only. A transient environment never
receives shipped changes that way: update its checkout and re-run
`./install.sh --transient`.

## Machines

Every hostname this repository names, whether a `chezmoi.hostname` that
templates gate on or an SSH destination. Role is derived at bootstrap from
the machine itself (`gnome-shell` on PATH, `systemd-detect-virt`), not from
the hostname, and describes only the machines chezmoi manages (see
Boundaries). What a role provides is described in the
[Provisioning model](.agents/docs/provisioning.md#roles-and-profile-data);
the Notes column records only host-specific overrides and hosts that are not
chezmoi targets.

| Hostname | OS | Role | Notes |
| --- | --- | --- | --- |
| x1 | Fedora Linux | desktop | the workstation laptop; the YubiKey 5C Nano stays in it, and its machine key is the only general authentication fallback |
| black | Fedora Linux | desktop | the desktop workstation |
| slate | macOS | desktop | configuration only, as for every Mac |
| Chloes-MBP | macOS | desktop | configuration only, like slate |
| slate-vm-work | Fedora Linux | desktop, vm | the managed VM |
| slate-vm-personal | Fedora Linux | server, vm | the personal server VM |
| greenhouse | Ubuntu Linux | server | headless; planned for decommissioning; older commits call it `netcup` |
| chalon | Raspberry Pi OS Lite | server | a Tailscale VPN gateway; an SSH destination, not a chezmoi target |
| git.terroir.systems | unrecorded | server | externally managed; an SSH destination, not a chezmoi target |

`github.com` is a service, not a machine. `xps13` appears in older commits
but is retired: a hostname found in the history is not evidence that the
machine still exists. Hostnames are compared lowercase, so the table's
`Chloes-MBP` is `chloes-mbp` in `managedHosts`. `server` is not
greenhouse-specific: personal servers remain first-class targets in that role.

Fedora desktops upgrade in place between releases; see
[Fedora upgrades](.agents/docs/upgrades.md).

## Boundaries

- This is a public GitHub repository - make sure no changes include private
  information that's cannot be freely disclosed. Raise a concern before
  publishing any changes if they are suspected to contain anything sensitive
  information.
- Deploy a tool's configuration only where a package script installs the
  tool: gate it in `.chezmoiignore.tmpl` (or the template) on the same OS,
  distro and role data. A gated target is left unmanaged where an earlier
  apply wrote it, not removed. The macOS non-developer configuration below is
  the deliberate exception.
- Gate tooling on role data, not hostnames; `vm` is independent of role. The
  one deliberate hostname gate is x1's machine-key authentication exception.
  See [Provisioning model](.agents/docs/provisioning.md) for detection,
  authentication exceptions, and sudo policy; see
  [Commit signing](.agents/docs/signing.md) for signing and agents.
- GitHub access is `gh` over HTTPS on every machine; only x1's machine key is
  registered for GitHub authentication. Preserve explicit repository signing
  overrides without silent fallback.
- macOS is managed for configuration only. Its developer environment is out
  of scope: do not reintroduce the Homebrew bundle or bootstrap, the launchd
  SSH agent, the Homebrew shell environment, or PATH shims. The apply may use
  the Mac's existing Homebrew to install `gh` and `jq`, the only tools its
  signing scripts call, and the Amp app; the Amp CLI comes from Amp's
  installer, as on Linux. Non-developer macOS configuration (KeePassXC settings,
  the iCloud notes symlink, terminal and appearance settings) belongs in the
  tree. Every macOS target is in `managedHosts`, so a Mac gets the full
  profile, not the transient one.
- Gate on the persisted `distro` key (`fedora`, `ubuntu`, `darwin`), not on
  `.chezmoi.osRelease`, which is empty off Linux: `text/template` evaluates
  both sides of `and`, so a combined condition still looks up the missing
  `id` key there.
- In `run_*` scripts, use `$CHEZMOI_SOURCE_DIR` (set by chezmoi when
  running scripts) rather than `chezmoi source-path`: a nested
  `chezmoi` invocation deadlocks on the parent `chezmoi apply`'s
  persistent-state lock.
