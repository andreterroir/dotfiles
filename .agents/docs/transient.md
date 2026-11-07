# Transient profile

A transient environment is a machine that may be discarded: an Amp orb, a
container, or a hostname outside `managedHosts` (including an unlisted VM).
The profile applies the full configuration inside that machine, but
establishes no identity and changes nothing outside it.

## Invocation

```sh
./install.sh --transient
```

The flag forces the profile. Without it, `chezmoi init` detects the
environment; `CHEZMOI_TRANSIENT=0` opts out. Run with `HOME` set to the
throwaway home, because scripts and package installs use `$HOME`; other
arguments go to `chezmoi apply`. The equivalent commands are:

```sh
CHEZMOI_TRANSIENT=1 chezmoi init --source=~/code/dotfiles
chezmoi apply --source=~/code/dotfiles
```

`install.sh` initialises first, so a later bare `chezmoi apply` or
`chezmoi update` uses the persisted profile.

## What runs

- Package installation, sudo setup, service definitions and enablement, and
  the file configuration (shell, Git, Vim, tmux, agent instructions) are
  applied. Packages, services, plugins, extensions, and externals change only
  the machine, so they are allowed.
- The shell is added to `/etc/shells` when the environment permits; `chsh`
  runs only when a terminal is available, so a non-interactive apply leaves
  the login shell unchanged.

## No identity

- No SSH keys are generated or downloaded, and none are registered with
  GitHub; the identity scripts exit early.
- No signing allowlist is fetched from GitHub.
- `~/.gitconfig` omits `commit.gpgsign`, `gpg.*`, and `user.signingKey`, so an
  environment-provided configuration such as Amp's `/etc/gitconfig` keeps
  signing. Elsewhere commits are unsigned.
- SSH agent services are not installed or enabled.

Nothing outside the machine changes. Package managers, plugin and extension
installers, and externals fetch into the machine; the apply does not modify
remote state.

## Detection

Init derives and persists the `transient` value:

- `CHEZMOI_TRANSIENT` wins when set. Any value except `0` or `false` enables
  the profile; `0` or `false` disables it.
- Otherwise the profile is enabled when `AMP_ORB` is set, when Linux reports
  a container (`systemd-detect-virt --container`), or when
  `chezmoi.hostname` is not in `managedHosts`. An unlisted VM is transient
  through its hostname.
- `managedHosts` in `.chezmoidata.toml` lists the chezmoi targets as lowercase
  short hostnames. Matching strips a `.local` suffix and ignores case. Keep it
  in sync with the Machines table in `AGENTS.md`; SSH-only destinations are
  deliberately absent. Run `chezmoi init` after changing it. Add a new
  physical machine before its first full apply, otherwise it is transient. If
  the list is missing, every host is transient.

A known VM such as `slate-vm-work` is not transient and keeps the machine-key
identity policy in [Provisioning model](provisioning.md). Force the profile on
a known host with `CHEZMOI_TRANSIENT=1`.

## Limits

The profile is not a sandbox. It installs packages and enables services with
the privileges the environment provides, so run it only in a machine that may
be discarded. It creates no SSH keys, starts no identity agent, and registers
nothing with GitHub; authentication comes from the environment, for example a
forwarded agent. It does not remove identity material left in a home that was
previously configured non-transient; start from a fresh home or delete the
keys, allowlist, and agent units yourself. Keep credentials and secrets out of
the destination.

The Amp runner service is gated in the transient profile: the runner script
exits before enabling, starting, or restarting it, so it does not register
with ampcode.com.
