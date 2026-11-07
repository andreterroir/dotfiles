# Neovim plugins

`private_dot_config/nvim/init.vim` declares the plugins; `plug-snapshot.vim` at
the repository root pins them. The snapshot is vim-plug's `:PlugSnapshot`
output, symlinked to `~/.config/nvim/plug-snapshot.vim` by
`symlink_plug-snapshot.vim.tmpl`. It records one commit per plugin plus
`PlugUpdate!`, so sourcing it installs missing plugins and checks installed
ones out at the pin.

The configuration is VimL. Every plugin still sets itself up from a `lua` line
touching its own module, because these plugins expose no VimL API; the
dashboard's multi-line table with a `footer` closure gets a heredoc in
`s:ConfigureDashboard()`. gitsigns hands each attached buffer to
`GitsignsMaps()`, so its keymaps stay in VimL. Per-machine overrides load
from `~/.config/nvim/init.local.vim`, with a leftover `init.local.lua` used
as a fallback.

`run_onchange_after_nvim-plugins.sh.tmpl` sources the snapshot and then
verifies every plugin against it, because a failed checkout does not fail
Neovim. Its `include` checksum makes the script re-run whenever the snapshot
changes. Never edit the snapshot by hand; regenerate it.

Pins are commits on each plugin's default branch, not releases. "Latest"
therefore means the branch head at upgrade time, and an unmaintained plugin
simply keeps its last commit.

## Upgrading

Upgrade in a throwaway `HOME` so the applied configuration stays at the old
pins until the new snapshot is committed and applied.

Match the Neovim version to the machines. Homebrew tracks stable and Fedora
and Ubuntu ship their own packages, so read the version from a real machine
(`brew info neovim`, `dnf info neovim`, `apt-cache policy neovim`) and use the
same release locally. Plugin minimums are in each plugin's README; gitsigns
requires Neovim 0.11, which is the floor for the fleet.

Seed the throwaway `HOME` with the config and the current pins:

    export H=/tmp/nvim-upgrade
    rm -rf "$H" && mkdir -p "$H/.config/nvim"
    cp private_dot_config/nvim/init.vim plug-snapshot.vim "$H/.config/nvim/"

Install the pins, then move every plugin to its branch head:

    HOME=$H nvim --headless -S "$H/.config/nvim/plug-snapshot.vim" -c 'qa!'
    HOME=$H nvim --headless '+PlugUpdate!' '+qa!'

`PlugUpdate!` prints almost nothing when headless, so confirm the result
directly. The date shows when each plugin's checked-out commit was last
changed upstream:

    for d in "$H"/.vim/plugged/*/; do
        n=$(basename "$d")
        printf '%-24s %-10s %s\n' "$n" "$(git -C "$d" rev-parse --short=9 HEAD)" \
            "$(git -C "$d" log -1 --format=%cs)"
    done

## Verifying

A clean start proves the plugins load and the configuration applies. Run it
with the config in place and check the reports, not just the exit status: the
color scheme, the options from `init.vim`, the commands each plugin adds, and
the commands the keymaps call.

    HOME=$H nvim --headless -c 'luafile /tmp/check.lua' -c 'qa!'

`check.lua` is a throwaway probe script (Neovim keeps Lua available for
probing plugin modules); make it assert `colors_name`, `tabstop`, `backupdir`,
`:Load`, `:Last`, `:Oil`, `:NoNeckPain`, `:UndotreeToggle`, `:Gitsigns` and
`:FzfLua`, plus `no-neck-pain`'s `width = 80`, the presence of every
`:Gitsigns` action the buffer maps call (`nav_hunk`, `stage_hunk`,
`blame_line`, ...), and the fzf-lua pickers used by the keymaps. Also dump
`:messages` and require it to be free of `nvim: plugin setup failed`.

Headless checks do not exercise windows. Run a real session in tmux with
`nvim -n` (no swap file, since abandoned test sessions otherwise block the
next start) and capture panes to confirm:

- the dashboard renders and its footer counts the plugins;
- gitsigns draws signs, and `stage_hunk`, `preview_hunk` and `diffthis` work;
- `oil` lists a directory, `no-neck-pain` opens two side columns, `toggleterm`
  opens a terminal, and `fzf-lua` opens its picker.

Then read what changed. For each moved plugin, `git log <old>..<new>` in its
checkout: a subject marked `!` is a breaking change, and `@deprecated` in the
plugin source names the calls to replace. The configuration touches these
APIs, so breakage shows up here rather than in startup:

| Plugin | Used by `init.vim` |
| --- | --- |
| gitsigns | `on_attach` → `GitsignsMaps()`, `:Gitsigns` `nav_hunk`, `stage_hunk`, `reset_hunk`, `stage_buffer`, `reset_buffer`, `preview_hunk`, `preview_hunk_inline`, `blame_line full=true`, `toggle_current_line_blame`, `diffthis`, `select_hunk` |
| fzf-lua | `setup`, and `:FzfLua` `files`, `live_grep`, `grep_cWORD`, `keymaps`, `oldfiles`, `helptags`, `resume` |
| dashboard | `setup` with the `doom` theme, the `center` entries, and the `footer` function |
| no-neck-pain | `setup { width = 80 }` |
| nvim-autopairs | `setup`, `add_rules` with a backtick `Rule` |
| persistence | `setup`, `:Load`, `:Last` |
| daybreak | `setup` with the GitHub color schemes |
| oil, toggleterm | `setup` (toggleterm's `open_mapping` is `<a-;>`) |

## Regenerating the pin

    HOME=$H nvim --headless '+PlugSnapshot! /tmp/plug-snapshot.vim' '+qa!'

Copy the result over the repository's `plug-snapshot.vim`; only the timestamp
and the commits that moved should differ. The run script's checksum line comes
from the file, so it needs no edit.

Validate the deploy path before committing. Render the script and run it
against a second clean `HOME` that holds only `init.vim` and the new snapshot;
it must exit 0, which means every plugin was checked out at the pin. Starting
Neovim there afterwards must produce the same clean startup report as above.
Then apply on a machine: `chezmoi apply` reinstalls the plugins at the new
commits and the run script verifies them.
