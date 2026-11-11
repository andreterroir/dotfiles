# Transient profile

A transient environment is one that may be discarded: a container, an Amp orb,
or a hostname outside `managedHosts` (including an unlisted VM). It receives
the portable set-up only — shell, Git, Vim, tmux, and agent instructions — with
no packages, no distribution dependencies, no services, and no identity, so
the same files apply anywhere it runs.

## Invocation

```sh
./install.sh
```

There is no flag or variable to force the profile: `chezmoi init` derives it
from the machine. Run with `HOME` set to the throwaway home, because the apply
writes into `$HOME`; other arguments go to `chezmoi apply`. The equivalent
commands are:

```sh
chezmoi init --source=~/code/dotfiles
chezmoi apply --source=~/code/dotfiles
```

`install.sh` initialises first, so a later bare `chezmoi apply` or
`chezmoi update` uses the persisted profile.

## What runs

- The portable file configuration: Vim and its pinned plugins, the
  `~/.bin/git-cleanup` helper, and the agent instructions at
  `~/.agents/AGENTS.md` and `~/.config/AGENTS.md`.
- Nothing installs packages or writes outside `$HOME`. The package, sudo, and
  mise scripts render empty, so no package manager, sudoers rule, or
  `mise install` runs.
- The host keeps its own shell, Git, and tmux configuration, so `~/.bashrc`,
  `~/.bash_profile`, `~/.gitconfig`, `~/.tmux.conf`, `~/.gitignore`, and
  `~/.bin/git-editor` stay as they are, and the tmux plugin script does not
  run. A harness that owns those files keeps its credential helper, hooks, and
  environment loading.
- `~/.ssh`, `~/.config/amp`, `~/.config/mise`, `~/.config/opencode`,
  `~/.config/systemd`, and `~/.config/topgrade.toml` are left unmanaged, so a
  forwarded agent, an existing SSH configuration, and the platform's own tool
  settings stay untouched.
- Vim plugins come from their upstream repositories, so a first apply needs
  network access; the script skips when Vim is absent.

## No identity

- The identity and signing-allowlist scripts are not part of this profile, so
  no SSH keys are generated or downloaded and none are registered with
  GitHub.
- No signing allowlist is fetched from GitHub.
- `~/.gitconfig` omits `commit.gpgsign`, `gpg.*`, and `user.signingKey`, so an
  environment-provided configuration such as Amp's `/etc/gitconfig` keeps
  signing. Elsewhere commits are unsigned.
- SSH agent services are not installed or enabled.

Nothing outside the machine changes. Plugin installers fetch into the machine;
the apply does not modify remote state.

## Detection

Init derives and persists three exclusive profile flags; this set-up is
`transient = true`.

- The profile is selected when Linux reports a container
  (`systemd-detect-virt --container`), when `AMP_ORB` is set, or when
  `chezmoi.hostname` is not in `managedHosts`. An unlisted VM is transient
  through its hostname.
- A headless host is fully provisioned only when it is `greenhouse`; every
  other headless host is transient.
- A host that is not Linux is transient too, so an apply on macOS or any
  other platform installs the portable files and nothing else. That is a
  fallback, not support: macOS stays unprovisioned and unsupported.
- `managedHosts` in `.chezmoidata.toml` lists the chezmoi targets as lowercase
  short hostnames. Matching strips a `.local` suffix and ignores case. Keep it
  in sync with the Machines table in `AGENTS.md`; SSH-only destinations are
  deliberately absent. Run `chezmoi init` after changing it. Add a new
  physical machine before its first full apply, otherwise it is transient. If
  the list is missing, every host is transient.

A managed VM such as `slate-vm-work` is not transient and keeps the machine-key
identity policy in [Provisioning model](provisioning.md). Virtualization is not
detected, so an orb, a container, or an unlisted VM never carries `vm`; see
[Provisioning model](provisioning.md) for the `managedVMs` list.

## Limits

It creates no SSH keys, starts no identity agent, and registers nothing with
GitHub; authentication comes from the environment, for example a forwarded
agent. It does not remove identity material left in a home that was previously
configured with another profile; start from a fresh home or delete the keys,
allowlist, and agent units yourself. Keep credentials and secrets out of the
destination.

The Amp runner is not part of this profile, so nothing registers with
ampcode.com.
