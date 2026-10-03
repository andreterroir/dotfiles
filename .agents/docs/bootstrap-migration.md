Bootstrap migration plan
========================

Step-by-step plan to move this repository to the simplified bootstrap
agreed in [the design thread](https://ampcode.com/threads/T-01a0f226-6610-7462-b59d-61a51c9e6adc).
Written so that an agent running on any one machine can execute the
steps assigned to that machine. Every step names its machine, what
must be true before it starts, the commands, and how to check it
worked. Steps that need a human at the keyboard (PIN, touch, browser
login, `sudo`) are marked **[human]**; an agent stops and asks there.

Target state
------------

| Concern | Today | Target |
| --- | --- | --- |
| Initial clone | SSH via YubiKey PIV + libykcs11 | HTTPS (`gh auth login`), later a public repo |
| Machine role | hostname allowlist frozen at `chezmoi init` | detected (`gnome-shell`, darwin), confirmed once at `init` |
| Interactive setup | `run_once_` scripts, alphabetical order | `run_` scripts with state checks, no-op without a TTY |
| Pinned CLI tools | sha-pinned tarballs in the Ubuntu script, copr, `curl \| bash` | `mise` from one `config.toml`; Terra RPMs on Fedora |
| SSH identity (desktop) | per-machine ed25519 + PIV fallback | one FIDO2 resident key per YubiKey (`ed25519-sk`) for interactive signing; machine ed25519 for unattended signing |
| SSH identity (server) | per-machine ed25519 | forwarded FIDO2 key for interactive signing and authentication; machine ed25519 for unattended signing only |
| `~/.allowed_signers` | committed per machine by a script | derived from GitHub's signing-key API on every apply |
| Secrets | `pass` + GnuPG on the YubiKey OpenPGP applet, store on greenhouse | `passage` + `age-plugin-yubikey` (PIV retired slot), store at `git.terroir.systems` |
| Shared env vars | duplicated in `.profile` and `config.fish` | one `~/.config/env`, installed to `environment.d` on Linux desktops |
| Repo visibility | private | public, after the store host is scrubbed from history |

Provisioning and use model
--------------------------

The four credential concerns are independent. A YubiKey represents an
interactive human; a machine-local key represents unattended work. `gh`
uses its OAuth token for GitHub API and HTTPS access, so no unattended
Git-over-SSH access is required.

| Aspect | Standard desktop | x1 | Interactive SSH session on a server | Unattended desktop or server | Slate exception |
| --- | --- | --- | --- | --- | --- |
| age passwords | Either YubiKey's `age-plugin-yubikey` identity decrypts the Passage store; the store remote is `git.terroir.systems` over SSH | Same | Not available | Not available | Slate is a desktop, but a machine-local age identity decrypts only its `work/` subtree; it never decrypts the root store, and repository sync still requires a YubiKey |
| Commit signing | Resident YubiKey SSH key; fail if it is unavailable | Same; the backup authentication key is not used for interactive signing | Forwarded resident YubiKey SSH key; fail if it is unavailable | Machine-local SSH key | No exception; standard desktop policy |
| Remote server access | Resident YubiKey SSH key; forward the agent to the server | Resident YubiKey preferred, with x1's machine-local SSH key as backup; forward the selected agent | The forwarded YubiKey authenticates onward connections | Not available by default; a local key may be explicitly authorized for a specific use | No exception; standard desktop policy |
| GitHub access | `gh` OAuth for API/HTTPS; resident YubiKey for SSH | `gh` OAuth for API/HTTPS; resident YubiKey or x1's machine-local backup key for SSH | `gh` OAuth for API/HTTPS; forwarded YubiKey for SSH | `gh` OAuth for API/HTTPS; no Git-over-SSH requirement | No exception; standard desktop policy |

Both YubiKey resident SSH keys are GitHub authentication and signing
keys and are authorized on the remote servers. Every machine-local key
is a GitHub signing key. Only x1's machine-local key is also a general
GitHub and remote-server authentication key. Local authentication keys
remain possible when explicitly authorized, but are not provisioned as
the default path.

Machines
--------

| Machine | OS | Role | Runner | YubiKey usually attached |
| --- | --- | --- | --- | --- |
| black | Fedora 45 Workstation | desktop | yes | YubiKey 5 NFC (serial 15596691) |
| x1 | Fedora Workstation | desktop | yes | YubiKey 5C Nano (serial 17644150) |
| greenhouse | Ubuntu, headless | server, Amp runner | yes | none |
| Chloes-MBP | macOS | desktop | no | either, when plugged in |
| slate | *unknown* | desktop, work machine | no | none |

Verified on both YubiKeys (firmware 5.4.3): PIV retired slots 82–95
free, FIDO2 resident keys supported, OpenSSH 10.x with `sk-ssh-ed25519`
and libfido2 present. The Nano has **no FIDO2 PIN set** yet. On both
keys the OpenPGP **admin PIN is blocked**, which does not matter once
GnuPG is retired. `age-plugin-yubikey` and `passage` have no Fedora
package and no Linux release binary; `age` is in Fedora.

Sequencing
----------

```
Phase 0  repository changes           one worktree, one agent (orb or any machine)
         0.1 → 0.2 → … → 0.9, merge to main, push

Phase 1  YubiKey prep [human]         black ║ x1          parallel, needs Phase 0.6 merged
Phase 2  password store move [human]  black               after Phase 1 on both keys

Phase 3  per-machine rollout          black ║ x1 ║ greenhouse ║ Chloes-MBP ║ slate
                                      parallel, after Phase 2 (desktops) / Phase 0 (servers)

Phase 4  retire old paths             one agent, after every machine reports Phase 3 done
         4.1 remove GnuPG/pass/PIV → 4.2 history scrub + force-push → 4.3 public
         → 4.4 every machine re-clones the source dir
```

Servers only depend on Phase 0; they may start Phase 3 as soon as `main`
carries the Phase 0 commits. Desktops, including Slate, wait for Phase 2
because their `run_` scripts clone the new store.

Phase 0 — repository changes
----------------------------

Run in a worktree (`git worktree add .wt/<name>`), validate each step
with `chezmoi --source "$(git rev-parse --show-toplevel)" apply --dry-run`
on the machine doing the work, one commit per step, ask before pushing.

### 0.1 mise replaces the pinned tarballs

- Add `private_dot_config/mise/config.toml.tmpl`:

      [tools]
      zig = "0.16.0"
      "ubi:exercism/cli" = { version = "3.5.8", exe = "exercism" }
      {{ if and .server (eq .chezmoi.os "linux") -}}
      "ubi:topgrade-rs/topgrade" = "17.12.2"
      {{ end -}}
      {{ if .desktop -}}
      rust = "stable"
      {{ end -}}
      {{ if .linux.desktop -}}
      "cargo:age-plugin-yubikey" = "0.5.1"
      {{ end -}}

  Fedora and macOS get topgrade from Terra/brew (0.2, 0.3), and macOS
  gets `age-plugin-yubikey` from brew, so the `cargo:` build is a Linux
  desktop tool only. `zig` and `exercism` leave every package list.
- Install mise itself per OS: Fedora `dnf` via mise's own repo
  (`https://mise.jdx.dev/rpm/mise.repo`), macOS `brew 'mise'`, Ubuntu
  via mise's apt repo (`https://mise.jdx.dev/deb`). Both repos go into
  the existing package scripts; keep the vendor's key-import steps. The
  vendor's apt key is ASCII-armored; apt accepts it as-is when the
  keyring file is named `.asc`, which avoids a `gpg --dearmor` step (and
  its gnupg dependency) on a fresh server.
- Add `run_onchange_after_mise-install.sh.tmpl` that embeds
  `{{ include "private_dot_config/mise/config.toml.tmpl" | sha256sum }}`
  in a comment and runs `mise install --yes`. Desktop Fedora also needs
  `pcsc-lite-devel` in its desktop dnf list for the `cargo:` build.
- Activate: `eval "$(mise activate bash)"` at the end of `dot_bashrc`,
  `mise activate fish | source` in `config.fish.tmpl`, and
  `~/.local/share/mise/shims` on PATH in `dot_profile.tmpl` and
  `config.fish.tmpl` so shells that never run the activate still find
  the tools.
- Delete the exercism, zig and topgrade blocks from
  `run_onchange_install-linux-packages.sh.tmpl`; leave chezmoi's
  installer, `gh`'s apt repo, opencode/amp/TPM for 0.2.
- Check: `mise ls` shows the tools; `zig version` prints 0.16.0 on
  Fedora and Ubuntu; `exercism version`.

### 0.2 Terra on Fedora

- In the Fedora branch of the Linux package script, before `dnf install`:

      if ! rpm -q terra-release >/dev/null; then
          sudo dnf install -y --nogpgcheck \
              --repofrompath "terra,https://repos.fyralabs.com/terra\$releasever" \
              terra-release terra-gpg-keys
      fi

  Main repo only: never `terra-release-extras`, `-mesa`, `-multimedia`.
- Add `ghostty`, `topgrade`, `opencode-cli` to the dnf list; remove the
  `lilay/topgrade` copr block and the opencode `curl | bash` block for
  Fedora. Keep the Flatpaks: Terra's Signal/Zotero/Spotify RPMs gain
  nothing over them.
- Check: `dnf repolist | grep terra`, `rpm -q ghostty topgrade opencode-cli`.

### 0.3 Package list hygiene (all OSes)

- Fedora: add `gnupg2-scdaemon` (only until Phase 4) and `age`, plus
  `pcsc-lite-devel` and `make` in the desktop block (`pcsc-lite-devel`
  for the `cargo:` build, `make` for the passage install). No `cargo`:
  mise brings the Rust toolchain.
- macOS Brewfile: add `age`, `age-plugin-yubikey`, `mise` and `openssh`;
  keep `ykman`. Apple's OpenSSH lacks built-in FIDO2 support; Homebrew
  OpenSSH depends on libfido2 and provides the `ssh-keygen -K` and
  `ssh-add -K` used by the identity script. There is no `passage` formula,
  so it is installed from source by the desktop run script (0.7).
- Ubuntu: nothing new; still no Node.

### 0.4 Role detection at init

Replace the `[data]` block in `.chezmoi.toml.tmpl`:

    [data]
        {{- $detected := or (eq .chezmoi.os "darwin") (ne (lookPath "gnome-shell") "") }}
        {{- $desktop := promptBoolOnce . "desktop" "Desktop machine" $detected }}
        desktop = {{ $desktop }}
        linux.desktop = {{ and $desktop (eq .chezmoi.os "linux") }}
        server = {{ not $desktop }}

`chezmoi init --promptBool 'Desktop machine=false'` overrides (the flag
keys on the prompt text, not on `desktop`). Document in
`AGENTS.md` that `desktop` is fixed until the next `chezmoi init`, and
drop the `black`/`x1` hostname rule from the Boundaries section.

### 0.5 `~/.allowed_signers` derived from GitHub

- Delete `dot_allowed_signers`. Add `run_after_allowed-signers.sh.tmpl`:

      #!/usr/bin/env bash
      set -euo pipefail
      out="$HOME/.allowed_signers"
      keys=$(curl -fsS --max-time 10 https://api.github.com/users/andreterroir/ssh_signing_keys \
          | jq -r '.[].key') || { echo '>allowed_signers: offline, keeping current file' >&2; exit 0; }
      [ -n "$keys" ] || exit 0
      tmp=$(mktemp) && printf 'andre@terroir.systems %s\n' $keys > "$tmp"
      ( [ -f "$out" ] && cmp -s "$tmp" "$out" ) && { rm "$tmp"; exit 0; }
      mv "$tmp" "$out" && echo '>allowed_signers updated'

  (`printf` with an unquoted `$keys` relies on one key per line; write
  it with a `while read` loop if the script is kept in Bash.)
- Check: `chezmoi apply` writes the current signing keys; `git log --show-signature -1` verifies.

### 0.6 SSH identity model

- `private_dot_ssh/private_config.tmpl`: keep authentication identities in
  host-specific blocks rather than under `Host *`. The managed config
  names only `github.com` and `git.terroir.systems`; both use
  `~/.ssh/id_ed25519_sk`, while x1 additionally offers its machine-local
  `~/.ssh/id_ed25519` as a backup:

      Host github.com git.terroir.systems
          IdentityFile ~/.ssh/id_ed25519_sk

  Other remote aliases and their `ForwardAgent yes` entries belong in
  untracked `~/.ssh/local_config` so the public repository does not name
  them.
  Both YubiKey public keys must be in each server's `authorized_keys`.
  x1's machine key is the only generally provisioned local-key backup.
- `dot_gitconfig.tmpl`: drop `user.signingkey`, add

      [gpg "ssh"]
          defaultKeyCommand = {{ .chezmoi.homeDir }}/.bin/git-signing-key

  git execs that command itself, so it needs an absolute path — a leading
  `~` is not expanded, unlike in `allowedSignersFile`, which is a path.
  `dot_bin/executable_git-signing-key` prints the first `sk-ssh-ed25519`
  line of `ssh-add -L` for any interactive terminal, including an SSH
  session. It must fail when an interactive session has no YubiKey key;
  it must not silently identify that commit as automation. For a
  non-interactive process it prints `~/.ssh/id_ed25519.pub`. Provide an
  explicit machine-key override for trusted tools that allocate a PTY,
  and document that override in the agent instructions.
- Replace `run_once_set-up-3-ssh.sh.tmpl` with `run_after_10-ssh-identity.sh.tmpl`:
  - `[ -t 0 ] || { echo '>ssh identity: run chezmoi apply from a terminal to finish'; exit 0; }`
  - desktop: if no `~/.ssh/id_ed25519_sk*`, **[human]** `ssh-keygen -K`
    in a temp dir, move the `_rk` files to `~/.ssh/id_ed25519_sk{,.pub}`,
    `ssh-add -K`.
  - every machine: if no `~/.ssh/id_ed25519`, generate a per-machine key
    for unattended signing.
  - register both YubiKey keys on GitHub as authentication and signing
    keys. Register every machine key as signing-only. Register x1's
    machine key additionally as an authentication key. Server machine
    keys do not need GitHub authentication because unattended Git uses
    HTTPS through `gh`.
  - use **[human]** `gh auth login --web` when registration needs it. No
    `git commit`, no `remote set-url`.
- Delete `run_once_set-up-1-gpg.sh.tmpl`.
- Check local and remote interactive commits use a YubiKey signature;
  both fail without that key. Check unattended commits use the local
  machine signature. `git log --show-signature -1` says Good for each.

### 0.7 passage replaces pass

- `private_dot_passage/plugin-identities.tmpl` (desktop): both YubiKeys'
  `AGE-PLUGIN-YUBIKEY-…` identity lines, filled in during Phase 1. The
  file holds slot references only, no secret material.
- `run_after_21-passage-identities.sh.tmpl` atomically builds Passage's
  `~/.passage/identities` from the managed plugin identities. Slate is
  the sole exception: its untracked `~/.passage/local-identities` holds
  the machine-local identity for the `work/` subtree.
- `run_onchange_after_20-passage-install.sh.tmpl` (desktop): install
  passage from a pinned git tag into `~/.local` with `make install`, the
  same way on Fedora, macOS, and Ubuntu (there is no package used here).
- `run_after_20-passage-store.sh.tmpl` (desktop): no-op without TTY; if
  `~/.passage/store` is missing, **[human]**
  `git clone git@git.terroir.systems:passwords.git ~/.passage/store`.
- `dot_bin/executable_update-passwords`: `passage git pull --rebase --quiet && passage git push --quiet`,
  exiting 0 when passage is absent or no permitted SSH authentication
  key is available. Desktops sync with a local YubiKey; x1 may use its
  backup machine key. The hook is a no-op on servers and during
  unattended runs without an authorized key.
- fish/bash: alias `pass=passage` for muscle memory; `PASSAGE_DIR` unset (default).
- Delete `run_once_set-up-2-pass.sh.tmpl`. Leave `pass`, `pass-otp`,
  gnupg config in place until Phase 4 so the migration machine has both.
- Check: template renders; `passage ls` on a machine with a store.

### 0.8 Shared environment file

- `private_dot_config/env`: `KEY=VALUE` lines (`CARGO_TARGET_DIR`,
  `RUSTUP_HOME`, `GOPATH`, `EDITOR`, `XZ_DEFAULTS`, `ZSTD_COMPRESS`,
  `LESS`); `$HOME` is allowed, both consumers expand it.
- Linux desktop: `private_dot_config/environment.d/symlink_10-dotfiles.conf.tmpl`
  → `{{ .chezmoi.homeDir }}/.config/env`.
- `dot_profile.tmpl`: `set -a; . "$HOME/.config/env"; set +a` replaces
  the individual exports; `config.fish.tmpl`: read the file line by
  line, `set -gx` each pair with `$HOME` expanded. PATH edits stay
  shell-specific.
- Check: new GNOME login → `systemctl --user show-environment | grep GOPATH`;
  `fish -c 'echo $GOPATH'`; `bash -lc 'echo $GOPATH'`.

### 0.9 Bootstrap docs and conditional symlinks

- `readme.md` Install section (private-repo phase):

      sudo dnf install -y gh git            # brew install gh chezmoi on macOS; apt on Ubuntu
      gh auth login --web --git-protocol https && gh auth setup-git
      sh -c "$(curl -fsLS get.chezmoi.io)" -- init --apply --purge-binary --source=~/code/dotfiles andreterroir

  Then `chezmoi apply` again from a terminal to finish the **[human]**
  steps. After Phase 4.3 the first two lines go away.
- `symlink_icloud.tmpl`, `symlink_cs.tmpl`, `private_dot_config/nvim/symlink_spell.tmpl`:
  wrap the target in `{{ if stat "<target>" }}` … `{{ end }}`. chezmoi
  skips a symlink whose rendered target is empty, so an absent
  Syncthing or notes folder produces no link instead of a dangling one.
- Remove the PIV section from the readme; `.agents/docs/yubikey-piv.md`
  is deleted in 4.1.
- Check: `chezmoi apply --dry-run` on a machine without `~/Sync` is silent.

Merge to `main` (fast-forward), push. Every machine then runs
`chezmoi update` (or `git -C ~/code/dotfiles pull` + `chezmoi init` to
re-render the config for 0.4) as the first step of its phase.

Phase 1 — YubiKey preparation [human], black ‖ x1
---------------------------------------------------

Once per key. Both machines in parallel; each machine works on the key
plugged into it. Needs 0.1–0.3 merged (tooling installed by `chezmoi apply`).

Where the two keys stand after the Phase 0 merge: both keys — the 5 NFC
(black, serial 15596691) and the Nano (x1, serial 17644150) — already
have their PIV management key stored on the YubiKey and PIN-protected,
with algorithm TDES, so neither needs `--protect` again. Retired slot 82
is still empty on both: no age identity exists yet, and the next write to
either key is `age-plugin-yubikey --generate` (step 4), after the merge
and a `chezmoi apply`. The 5 NFC also has its resident SSH key registered
(`ssh -T git@github.com` answers `Hi andreterroir!`). The `pass` copies of
both old management keys are stale.

1. `chezmoi update && chezmoi init` (re-render config) and confirm
   `chezmoi data | jq .desktop` is `true`.
2. Nano only: set a FIDO2 PIN — `ykman fido access change-pin`.
3. Resident SSH key: `ssh-keygen -t ed25519-sk -O resident -O application=ssh:<5nfc|nano> -C "yubikey-<5nfc|nano>" -f ~/.ssh/id_ed25519_sk`
   (PIN + touch). Register: `gh ssh-key add ~/.ssh/id_ed25519_sk.pub --title yubikey-<name>`
   and again with `--type signing`. Verify `ssh -T git@github.com`.
   Done on the 5 NFC.
4. age identity: retired slot 82 is empty on both keys, so this is the
   first write to either of them. `age-plugin-yubikey` 0.5.1 neither
   prompts for the PIV management key nor accepts an unprotected or AES
   key, and both keys already store their management key on the YubiKey
   PIN-protected, so there is no `change-management-key` step here.
   `age-plugin-yubikey --generate --slot 1 --name <5nfc|nano> --pin-policy once --touch-policy cached > /tmp/id.txt`
   (asks for the PIN). Slot 1 is retired slot 82. Paste the
   `AGE-PLUGIN-YUBIKEY-…` line into
   `private_dot_passage/plugin-identities.tmpl` and the
   `age1yubikey1…` recipient into the store's `.age-recipients` (Phase 2).
5. Commit the identity line to the dotfiles branch; x1 sends its
   recipient/identity to black (public data, any channel).

Phase 2 — password store move [human], black
--------------------------------------------

Needs both recipients from Phase 1 and both keys' identities on black
(the Nano can stay in x1: encryption to a recipient needs no hardware,
only decryption does).

1. Create an empty private bare repository at
   `git@git.terroir.systems:passwords.git`. Authorize both YubiKey SSH
   keys and x1's backup key on the host; do not link the repository to
   an external identity provider.
2. `mkdir -p ~/.passage/store && printf '%s\n' age1yubikey1…5nfc age1yubikey1…nano > ~/.passage/store/.age-recipients`;
   `passage git init`; `passage git remote add origin git@git.terroir.systems:passwords.git`.
3. Migrate (312 entries; GnuPG user PIN once, agent caches it):

       cd ~/.password-store && find . -name '*.gpg' -printf '%P\n' | sed 's/\.gpg$//' |
       while read -r n; do pass show "$n" | passage insert -m "$n"; done

   `pass-otp` has zero `otpauth://` entries; eyeball the list anyway.
4. `passage git add -A && passage git commit -m 'Migrate from pass' && passage git push -u origin main`.
5. The `work/` subtree remains Slate-only. Before migrating it, generate
   an age identity in `~/.passage/local-identities` on Slate and commit
   only its recipient to `work/.age-recipients`. Passage uses the nearest
   recipients file, so `work/*` does not inherit the root YubiKey recipients.
   Never export or commit Slate's local identity.
6. Verify on black (5 NFC, touch): `passage show <entry>`. Verify on x1
   after Phase 3 with the Nano, and verify a `work/*` entry only on Slate.
   Only then treat the pass store as read-only.
7. Fill both `AGE-PLUGIN-YUBIKEY-…` lines into `plugin-identities.tmpl`, merge.

Phase 3 — per-machine rollout (parallel)
----------------------------------------

Common first step on every machine: `git -C ~/code/dotfiles pull --ff-only && chezmoi init && chezmoi apply`
from a real terminal (the **[human]** `run_` steps need it). Check
`chezmoi data | jq '{desktop, server}'` before anything else.

### black, x1 (Fedora desktops)

1. Common step. Expect: Terra enabled, `ghostty`/`topgrade`/`opencode-cli`
   RPMs, `mise install` (rust + `age-plugin-yubikey` build takes minutes),
   `passage` installed from source into `~/.local`,
   `~/.allowed_signers` regenerated, `~/.ssh/id_ed25519_sk` already
   present from Phase 1 so the ssh script only checks GitHub,
   `~/.passage/store` cloned.
2. `passage show <entry>` decrypts with the local key.
3. `git commit --allow-empty -m test` in any repo: YubiKey blinks, touch,
   `git log --show-signature -1` → Good.
4. Remove the YubiKey and confirm an interactive commit fails. Run an
   unattended commit with the machine-key override and confirm its
   signature is the local machine key.
5. Confirm SSH authentication without a YubiKey fails on black. On x1,
   confirm the machine-local backup still authenticates to a remote
   server, GitHub, and `git.terroir.systems`.
6. New GNOME session; `systemctl --user show-environment | grep -c 'GOPATH\|EDITOR'` → 2.
7. Report: `chezmoi status` empty, `mise ls`, `dnf repolist | grep terra`.

### greenhouse (Ubuntu server, Amp runner)

`~/code/dotfiles` already resolves to the live repository (it is a
symlink to the runner's `~/.local/share/chezmoi`), so there is no
source-directory migration to perform; `chezmoi source-path` confirms
it.

1. Common step; `desktop` must be `false`.
2. Expect: mise from its apt repo with `topgrade`, `zig`, `exercism`;
   the tarball code is gone. `~/.ssh/id_ed25519` already exists; the
   ssh script registers it on GitHub as a **signing-only** key if missing
   (**[human]** `gh auth login` once, or reuse the runner's existing
   `gh` login).
3. Unattended signing check as the runner does it: `git -C ~/code/dotfiles commit --allow-empty -m test`
   with no forwarded agent → Good signature from the machine key.
4. From a desktop, authenticate to the server and forward the resident
   key. An interactive commit on the server uses that forwarded key and
   fails if it is absent. Unattended commits use the server's local key.
5. GitHub API and unattended Git access use `gh` OAuth and HTTPS. In an
   interactive session, `ssh -T git@github.com` uses the forwarded
   YubiKey; it fails when that key is unavailable.

### Chloes-MBP (macOS desktop, no runner)

1. `brew bundle` runs from the package script: `age`,
   `age-plugin-yubikey` and `mise` arrive, and the desktop run script
   installs `passage` from source (there is no formula for it);
   `pinentry-mac`, `pass`, `gnupg` stay until 4.1.
2. Common step. **[human]** with a YubiKey plugged in: `ssh-keygen -K`
   downloads the resident key handle (the `run_` script drives this).
   `ssh-add -K` loads it; macOS `UseKeychain` is unaffected because
   there is no PKCS#11 provider any more.
3. `passage show`, signed commit, as on Fedora.
4. Repeat Fedora's interactive-without-YubiKey and unattended-signing
   checks. SSH authentication without a YubiKey must fail.
5. `environment.d` does not apply; check `fish -c 'echo $GOPATH'` and a
   login bash instead.

### slate (work desktop)

Run the desktop rollout for Slate's OS; `chezmoi data` must report
`desktop: true`. Plug in either YubiKey for initial store cloning, root
password decryption, interactive signing, and SSH authentication. Place
Slate's machine-local age identity in untracked
`~/.passage/local-identities`; verify it decrypts a `work/*` entry but
not a root entry. Also run the standard desktop checks: an interactive
commit without a YubiKey fails, an unattended commit uses Slate's local
SSH key, and SSH authentication without a YubiKey fails.

Phase 4 — retire the old paths
------------------------------

Only after all five machines report Phase 3 complete, `passage` works
on every desktop, and Slate's local age identity can decrypt only its
`work/` subtree.

### 4.1 Remove GnuPG, pass, PIV (repo)

- Delete `private_dot_gnupg/`, `.agents/docs/yubikey-piv.md`, the
  readme PIV section, `symlink_icloud`-style leftovers noted in 0.9.
- Package lists: drop `pass`, `pass-otp`, `gnupg2-scdaemon`,
  `yubico-piv-tool`, `pinentry-mac`, `gnupg` (macOS). Keep `gnupg2` on
  Fedora (system dependency), `yubikey-manager`/`ykman`, `pcsc-tools`.
- `private_dot_ssh/private_config.tmpl`: remove desktop machine keys from
  authentication except for x1's host-specific backup. Remove the other
  machine keys from GitHub authentication and server `authorized_keys`;
  both YubiKey keys must be authorized first.
  Retain `~/.ssh/id_ed25519{,.pub}` and its GitHub signing-key
  registration: non-interactive Git signing continues to use the
  machine key.
- `.chezmoi.toml.tmpl`: the `hooks.update.post` line keeps calling
  `update-passwords`, now passage-backed.
- On greenhouse, archive then delete `~/.password-store` (`tar` to a
  passage-encrypted blob or just delete once the new store has the history).
  Remove the PIV public key from greenhouse's `authorized_keys` and GitHub.

### 4.2 Scrub the store host from history [human]

On a fresh clone, put the legacy store hostname and account identifiers
in a private `git filter-repo --replace-text` file, replace each with
`REDACTED`, and search the rewritten history for every original value.
Delete the replacements file, then force-push `main` — **ask before the
push**. Every machine then re-clones:
`rm -rf ~/code/dotfiles && chezmoi init --apply --source=~/code/dotfiles andreterroir`
(state is in `~/.config/chezmoi`, so `run_once_` history survives;
the new `run_` scripts do not depend on it).

### 4.3 Make the repository public

`gh repo edit andreterroir/dotfiles --visibility public`. Update the
readme install to the one-liner; `gh auth login` moves from the
prerequisites into the **[human]** step list (only needed to upload
keys).

Terra
-----

Enable Terra's main repo on Fedora; do not enable any subrepo. It is
the officially documented Ghostty install path and gives `ghostty`,
`topgrade` and `opencode-cli` as RPMs, which removes the copr and the
opencode `curl | bash` installer. `mise` is in Terra too, but the
scripts take it from mise's own repositories so Fedora and Ubuntu
install it the same way. It does not help the identity migration:
`age-plugin-yubikey` and `passage` are not in Terra, and neither are
`amp`, `chezmoi`, `exercism` or `syncthing`. Rule of thumb after this
migration: distro or Terra RPM for anything with system integration
(terminal, fonts, pcscd, gh), `mise` for user-space tools that must
match across OSes, Flatpak for GUI apps, brew for everything on macOS.
Terra's Rust packages fetch crates at build time rather than vendoring,
so it is a small step down from Fedora's supply-chain guarantees;
acceptable for the three packages above.

Rollback
--------

Before 4.2 every step is additive: the old `pass` store, GnuPG config,
per-machine keys and PIV key keep working alongside the new ones. If
passage or sk keys misbehave on a machine, `chezmoi init --promptBool 'Desktop machine=false'`
is *not* the answer (it would strip GUI setup); revert the specific
commit in the dotfiles instead. After 4.2 the history rewrite is the
only irreversible step, which is why it waits for every machine.
