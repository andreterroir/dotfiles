# Vim plugins

`dot_vimrc` declares the plugins; `plug-snapshot.vim` at the repository root
pins them. The snapshot is vim-plug's `:PlugSnapshot` output, symlinked to
`~/.vim/plug-snapshot.vim` by `dot_vim/symlink_plug-snapshot.vim.tmpl`. It
records one commit per plugin plus `PlugUpdate!`, so sourcing it installs
missing plugins and checks installed ones out at the pin.

The configuration is legacy Vim script and uses no Lua or Neovim API calls.
Plugins configure themselves through VimL globals: startify's command list, which-key's description dictionary,
floaterm's toggle, gitgutter's maps (disabled in favour of the explicit ones in
`dot_vimrc`) and goyo's width. Per-machine overrides load from
`~/.vim/init.local.vim`.

Backups and editor state stay outside the working tree: `~/.cache/vim/backup`
for backups, `~/.local/state/vim` for swap files, undo history and sessions.

`run_onchange_after_vim-plugins.sh.tmpl` sources the snapshot, removes plugins
the configuration no longer declares, and verifies every plugin against the
snapshot, because a failed checkout does not fail Vim. Its `include` checksum
makes the script re-run whenever the snapshot changes. Never edit the snapshot
by hand; regenerate it.

Pins are commits on each plugin's default branch, not releases. "Latest"
therefore means the branch head at upgrade time, and an unmaintained plugin
simply keeps its last commit.

## Upgrading

Upgrade in a throwaway `HOME` so the applied configuration stays at the old
pins until the new snapshot is committed and applied.

The fleet runs Vim 9 from Fedora or Ubuntu, which is well above every
plugin's minimum. Plugin requirements are in each plugin's README. Ubuntu's
`vim` package is a `-clipboard` build, so the clipboard maps in
[Shortcuts](shortcuts.md) do not exist there.

Seed the throwaway `HOME` with the config and the current pins:

    export H=/tmp/vim-upgrade
    rm -rf "$H" && mkdir -p "$H/.vim"
    cp dot_vimrc "$H/.vimrc"
    cp plug-snapshot.vim "$H/.vim/plug-snapshot.vim"

Install the pins, then move every plugin to its branch head:

    HOME=$H vim -Nu "$H/.vimrc" -es -S "$H/.vim/plug-snapshot.vim" -c 'qa!'
    HOME=$H vim -Nu "$H/.vimrc" -es -c 'PlugUpdate!' -c 'qa!'

`PlugUpdate!` prints little in Ex mode, so confirm the result directly. The
date shows when each plugin's checked-out commit was last changed upstream:

    for d in "$H"/.vim/plugged/*/; do
        n=$(basename "$d")
        printf '%-24s %-10s %s\n' "$n" "$(git -C "$d" rev-parse --short=9 HEAD)" \
            "$(git -C "$d" log -1 --format=%cs)"
    done

## Verifying

A clean start proves the plugins load and the configuration applies. Run it
with the config in place and check the reports, not just the exit status: the
options from `dot_vimrc`, the commands each plugin adds, and the commands the
keymaps call.

    HOME=$H vim -Nu "$H/.vimrc" -es -c 'call writefile([&backupdir, exists(":Goyo"), exists(":GitGutterNextHunk"), exists(":FloatermToggle"), exists(":Startify"), exists(":Dirvish"), exists(":Load")], "/tmp/report")' -c 'qa!'

Also require `:messages` to be free of `vim: plugin setup failed` and of
`vim-plug: plugin(s) missing`.

Ex mode does not exercise windows. Run a real session in a terminal and check:

- the buffer renders in the terminal theme's foreground and background, with
  no colorscheme and no syntax highlighting;
- startify renders its commands, recent files and footer;
- gitgutter draws signs, `]c` and `[c` move between hunks, and
  `<leader>hs` stages a hunk;
- `-` opens dirvish, `:Goyo` centers at 80 columns, `<A-;>` toggles the
  floaterm, and `<leader>` opens which-key;
- `:Load` restores the session for the directory and branch, `:Last` the most
  recently written one.

Then read what changed. For each moved plugin, `git log <old>..<new>` in its
checkout: a subject marked `!` is a breaking change, and `@deprecated` in the
plugin source names the calls to replace. The configuration touches these
APIs, so breakage shows up here rather than in startup:

| Plugin | Used by `dot_vimrc` |
| --- | --- |
| vim-startify | header, lists, commands, footer with the plugin count |
| vim-which-key | `g:which_key_map`, `:WhichKey` and `:WhichKeyVisual` |
| lexima.vim | default pair rules |
| vim-floaterm | `g:floaterm_keymap_toggle` (`<A-;>`) |
| vim-gitgutter | map keys off, then `]c`, `[c`, stage, undo, preview, blame and the `ih` text object |
| vim-dirvish | `-` to open the parent directory |
| goyo.vim | `g:goyo_width = 80`, `<leader>tc` |
| fzf.vim | `:Files`, `:Rg`, `:Maps`, `:History`, `:Helptags` |
| vim-fugitive | `:Git add`, `:Git restore`, `:Git blame`, `:Gdiffsplit` |

fzf.vim requires fzf 0.63 or newer. Fedora ships a newer release, and
Ubuntu 26.04 ships 0.67. On Ubuntu 24.04, whose package is 0.44, the first
picker offers to download a binary into the plugin directory instead.

## Regenerating the pin

    HOME=$H vim -Nu "$H/.vimrc" -es -c 'PlugSnapshot! /tmp/plug-snapshot.vim' -c 'qa!'

Copy the result over the repository's `plug-snapshot.vim`; only the timestamp
and the commits that moved should differ. The run script's checksum line comes
from the file, so it needs no edit.

Validate the deploy path before committing. Render the script and run it
against a second clean `HOME` that holds only `.vimrc` and the new snapshot;
it must exit 0, which means every plugin was checked out at the pin. Starting
Vim there afterwards must produce the same clean startup report as above.
Then apply on a machine: `chezmoi apply` reinstalls the plugins at the new
commits and the run script verifies them.
