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
| SSH identity (server) | per-machine ed25519 | unchanged, registered on GitHub as auth + signing |
| `~/.allowed_signers` | committed per machine by a script | derived from GitHub's signing-key API on every apply |
| Secrets | `pass` + GnuPG on the YubiKey OpenPGP applet, store on netcup | `passage` + `age-plugin-yubikey` (PIV retired slot), store in a private GitHub repo |
| Shared env vars | duplicated in `.profile` and `config.fish` | one `~/.config/env`, installed to `environment.d` on Linux desktops |
| Repo visibility | private | public, after the store host is scrubbed from history |

Machines
--------

| Machine | OS | Role | Runner | YubiKey usually attached |
| --- | --- | --- | --- | --- |
| black | Fedora 45 Workstation | desktop | yes | YubiKey 5 NFC (serial 15596691) |
| x1 | Fedora Workstation | desktop | yes | YubiKey 5C Nano (serial 17644150) |
| netcup (`greenhouse`) | Ubuntu, headless | server, Amp runner | yes | none |
| Chloes-MBP | macOS | desktop | no | either, when plugged in |
| slate | *unknown; assumed Ubuntu server* | server | no | none |

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

Phase 3  per-machine rollout          black ║ x1 ║ netcup ║ Chloes-MBP ║ slate
                                      parallel, after Phase 2 (desktops) / Phase 0 (servers)

Phase 4  retire old paths             one agent, after every machine reports Phase 3 done
         4.1 remove GnuPG/pass/PIV → 4.2 history scrub + force-push → 4.3 public
         → 4.4 every machine re-clones the source dir
```

Servers only depend on Phase 0; they may start Phase 3 as soon as
`main` carries the Phase 0 commits. Desktops wait for Phase 2 because
their `run_` scripts clone the new store.

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
- macOS Brewfile: add `age`, `age-plugin-yubikey` and `mise`; keep
  `ykman`. There is no `passage` formula, so it is installed from source
  by the desktop run script (0.7).
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

- `private_dot_ssh/private_config.tmpl`: add `IdentityFile ~/.ssh/id_ed25519_sk`
  under `Host *` on desktops (keep `~/.ssh/id_ed25519` too until 4.1), and

      Host REDACTED greenhouse slate
          ForwardAgent yes

  on desktops only, so `git commit` on a server signs with the plugged
  YubiKey.
- `dot_gitconfig.tmpl`: drop `user.signingkey`, add

      [gpg "ssh"]
          defaultKeyCommand = {{ .chezmoi.homeDir }}/.bin/git-signing-key

  git execs that command itself, so it needs an absolute path — a leading
  `~` is not expanded, unlike in `allowedSignersFile`, which is a path.
  `dot_bin/executable_git-signing-key` prints the first `sk-ssh-ed25519`
  line of `ssh-add -L` only when stdin is a TTY; otherwise it prints
  `~/.ssh/id_ed25519.pub` if it exists, else exits 1. Interactive work
  therefore uses a plugged-in (or forwarded) YubiKey, while unattended
  work signs with the machine key without waiting for a touch.
- Replace `run_once_set-up-3-ssh.sh.tmpl` with `run_after_10-ssh-identity.sh.tmpl`:
  - `[ -t 0 ] || { echo '>ssh identity: run chezmoi apply from a terminal to finish'; exit 0; }`
  - desktop: if no `~/.ssh/id_ed25519_sk*`, **[human]** `ssh-keygen -K`
    in a temp dir, move the `_rk` files to `~/.ssh/id_ed25519_sk{,.pub}`,
    `ssh-add -K`.
  - server: if no `~/.ssh/id_ed25519`, `ssh-keygen -t ed25519 -C "$(hostname -s) $(date +%F)"`.
  - both: check the public key against `api.github.com/users/andreterroir/keys`
    and `/ssh_signing_keys` (already in the old script); if missing,
    **[human]** `gh auth login --web` if needed, then `gh ssh-key add`
    as auth and as signing. No `git commit`, no `remote set-url`.
- Delete `run_once_set-up-1-gpg.sh.tmpl`.
- Check: `ssh -T git@github.com` (touch), `git commit --allow-empty -m test`
  signs, `git log --show-signature -1` says Good.

### 0.7 passage replaces pass

- `private_dot_passage/plugin-identities.tmpl` (desktop): both YubiKeys'
  `AGE-PLUGIN-YUBIKEY-…` identity lines, filled in during Phase 1. The
  file holds slot references only, no secret material.
- `run_after_21-passage-identities.sh.tmpl` atomically builds Passage's
  `~/.passage/identities` from the managed plugin identities plus an
  optional, untracked `~/.passage/local-identities`. This lets Slate add
  its local age secret without chezmoi overwriting it or putting it in Git.
- `run_onchange_after_20-passage-install.sh.tmpl` (desktop): install
  passage from a pinned git tag into `~/.local` with `make install`, the
  same way on Fedora and macOS (there is no package on either).
- `run_after_20-passage-store.sh.tmpl` (desktop): no-op without TTY; if
  `~/.passage/store` is missing, **[human]**
  `git clone https://github.com/andreterroir/passwords ~/.passage/store`.
- `dot_bin/executable_update-passwords`: `passage git pull --rebase --quiet && passage git push --quiet`,
  exiting 0 when passage is absent so the `chezmoi update` hook is a
  no-op on servers.
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
   `private_dot_passage/identities.tmpl` and the
   `age1yubikey1…` recipient into the store's `.age-recipients` (Phase 2).
5. Commit the identity line to the dotfiles branch; x1 sends its
   recipient/identity to black (public data, any channel).

Phase 2 — password store move [human], black
--------------------------------------------

Needs both recipients from Phase 1 and both keys' identities on black
(the Nano can stay in x1: encryption to a recipient needs no hardware,
only decryption does).

1. `gh repo create andreterroir/passwords --private` (empty).
2. `mkdir -p ~/.passage/store && printf '%s\n' age1yubikey1…5nfc age1yubikey1…nano > ~/.passage/store/.age-recipients`;
   `passage git init`; `passage git remote add origin https://github.com/andreterroir/passwords.git`.
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
4. New GNOME session; `systemctl --user show-environment | grep -c 'GOPATH\|EDITOR'` → 2.
5. Report: `chezmoi status` empty, `mise ls`, `dnf repolist | grep terra`.

### netcup / greenhouse (Ubuntu server, Amp runner)

`~/code/dotfiles` already resolves to the live repository (it is a
symlink to the runner's `~/.local/share/chezmoi`), so there is no
source-directory migration to perform; `chezmoi source-path` confirms
it.

1. Common step; `desktop` must be `false`.
2. Expect: mise from its apt repo with `topgrade`, `zig`, `exercism`;
   the tarball code is gone. `~/.ssh/id_ed25519` already exists; the
   ssh script registers it on GitHub as **signing** key if missing
   (**[human]** `gh auth login` once, or reuse the runner's existing
   `gh` login).
3. Unattended signing check as the runner does it: `git -C ~/code/dotfiles commit --allow-empty -m test`
   with no forwarded agent → Good signature from the machine key.
4. From a desktop: `ssh -A greenhouse 'ssh-add -L'` shows the sk key;
   a commit there signs via the YubiKey.

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
4. `environment.d` does not apply; check `fish -c 'echo $GOPATH'` and a
   login bash instead.

### slate (assumed Ubuntu server)

Same as netcup, minus the runner-specific source-dir fix. If slate is
in fact a Mac or a desktop, run the Chloes-MBP or Fedora list instead;
confirm with `chezmoi data` before applying.

Phase 4 — retire the old paths
------------------------------

Only after all five machines report Phase 3 complete and `passage`
works on every desktop.

### 4.1 Remove GnuPG, pass, PIV (repo)

- Delete `private_dot_gnupg/`, `.agents/docs/yubikey-piv.md`, the
  readme PIV section, `symlink_icloud`-style leftovers noted in 0.9.
- Package lists: drop `pass`, `pass-otp`, `gnupg2-scdaemon`,
  `yubico-piv-tool`, `pinentry-mac`, `gnupg` (macOS). Keep `gnupg2` on
  Fedora (system dependency), `yubikey-manager`/`ykman`, `pcsc-tools`.
- `private_dot_ssh/private_config.tmpl`: drop `IdentityFile ~/.ssh/id_ed25519`
  on desktops and remove those keys from GitHub authentication and from
  `~/.ssh/authorized_keys` on the servers (the sk keys must be in
  `authorized_keys` first: `ssh-copy-id -i ~/.ssh/id_ed25519_sk.pub greenhouse`).
  Retain `~/.ssh/id_ed25519{,.pub}` and its GitHub signing-key
  registration: non-interactive Git signing continues to use the
  machine key.
- `.chezmoi.toml.tmpl`: the `hooks.update.post` line keeps calling
  `update-passwords`, now passage-backed.
- On netcup, archive then delete `~/.password-store` (`tar` to a
  passage-encrypted blob or just delete once GitHub has the history).
  Remove the PIV public key from netcup's `authorized_keys` and GitHub.

### 4.2 Scrub the store host from history [human]

`git filter-repo --replace-text <(printf 'REDACTED==>REDACTED\nREDACTED@netcup==>REDACTED\n')`
on a fresh clone, review `git log -p -S netcup`, then force-push
`main` — **ask before the push**. Every machine then re-clones:
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
