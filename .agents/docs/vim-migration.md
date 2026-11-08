# Neovim to Vim migration

The editor configuration targets plain Vim. `private_dot_config/nvim/init.vim`
became `dot_vimrc` (`~/.vimrc`), the spell and snapshot symlinks moved to
`dot_vim/` (`~/.vim/`), and the migration merged as `a7649cb`. This page records
what the old setup did, what replaced it and what the replacement does not do.
[Shortcuts](shortcuts.md) lists the keys, including the ones deliberately
dropped; [Vim plugins](vim-plugins.md) covers pinning, upgrading and verifying
the plugin set.

## What moved

- `~/.config/nvim/init.vim` → `~/.vimrc`; `~/.config/nvim/` → `~/.vim/`.
  vim-plug bootstraps into `~/.vim/autoload/plug.vim` and installs into
  `~/.vim/plugged/`, and the snapshot is symlinked to
  `~/.vim/plug-snapshot.vim`. The spell symlink moved to `~/.vim/spell` and
  still points at the same `~/Sync/apps/nvim/spell` data directory as before.
- Per-machine overrides moved from `~/.config/nvim/init.local.vim` to
  `~/.vim/init.local.vim`. The `init.local.lua` fallback is gone.
- No part of the configuration is Lua any more. Plugin settings are VimL
  globals (startify's lists and commands, `g:which_key_map`, floaterm's
  toggle, `g:gitgutter_map_keys`, goyo's width), and maps are built by one
  `s:Map` helper with `:noremap` instead of `nvim_set_keymap`. The pinned set
  goes from 20 plugins to 19: fzf and fzf.vim together replace fzf-lua and
  nvim-web-devicons, and the rest either keep their pins or are replaced in
  the table below.
- Backups live in `~/.cache/vim/backup`; swap files, undo history and sessions
  in `~/.local/state/vim`. Neovim kept them under `~/.cache/nvim` and
  `~/.local/state/nvim`; `undofile` itself is unchanged.

Neovim left the rest of the repository with it:

| Where | Before | Now |
| --- | --- | --- |
| Fedora packages | `neovim` | `vim-enhanced` |
| Ubuntu packages | `neovim` | `vim` |
| `EDITOR` in `dot_bash_profile.tmpl` | `nvim` | `vim` |
| `v` and `vi` aliases in `dot_bashrc` | `nvim` | `vim` |
| Git editor `~/.bin/git-editor` | `exec nvim` | `exec vim` |
| Git mergetool and `merge.tool` | `nvim -c Gvdiffsplit!` | `vim -c Gvdiffsplit!` |
| chezmoi `[merge]` command | `nvim` | `vim` |
| tmux `focus-events` comment | "Enable Neovim focus events" | "Enable Vim focus events" |

`.chezmoiremove` still retires what an apply cannot: a leftover
`~/.config/nvim/init.lua`, the old `lazy-lock.json` symlink, and the
`~/.local/share/nvim/lazy` clones. Nothing in this repository configures
Neovim now, so a hand-installed Neovim no longer picks up the old
configuration.

## Plugins replaced

| Before | Now | What still works |
| --- | --- | --- |
| `github-nvim-theme` | `cormacrelf/vim-colors-github` | a GitHub colorscheme with light and dark variants |
| `daybreak.nvim` (Lua) | `daybreak.nvim` Vim port | following the system appearance, on macOS, Linux and Windows |
| `no-neck-pain.nvim` | `goyo.vim` | centering the focused buffer at 80 columns |
| `nvim-autopairs` | `lexima.vim` | pair insertion, step-over, backspace, newline between pairs |
| `which-key.nvim` | `vim-which-key` | a leader popup with labels |
| `persistence.nvim` | built-in `:mksession` functions | `:Load` and `:Last`, one session per directory |
| `fzf-lua` + `nvim-web-devicons` | `junegunn/fzf` + `fzf.vim` | file, grep, keymap, history and help pickers |
| `dashboard-nvim` | `vim-startify` | a startup screen with commands and recent files |
| `toggleterm.nvim` | `vim-floaterm` | a toggleable terminal on `<A-;>` |
| `gitsigns.nvim` | `vim-gitgutter` + `vim-fugitive` | signs, hunk jumps, hunk staging, blame, diffs |
| `oil.nvim` | `vim-dirvish` | a directory listing opened with `-` |

### What each replacement does not do

**goyo for no-neck-pain.** goyo opens a new tab with padding windows on both
sides and one centered window; in it, line numbers, ruler, statusline and
tabline are hidden — the cursor line stops showing too, because
`cursorlineopt=number` highlights the number column goyo removes — gitgutter
signs and statusline plugins are switched off, and the padding is not editable.
no-neck-pain kept the current tab and its split layout, centering the focused
buffer while the side buffers stayed visible and usable. That layout no longer
exists: centering costs a tab, the other buffers are a tab away, and the splits
are not preserved. The width is still 80 columns (`g:goyo_width`), and
`<leader>tc` still toggles it.

**lexima for nvim-autopairs.** lexima inserts the closing pair, steps over an
existing closer, deletes both on backspace, opens a newline between pairs, and
carries its own rules for backticks, including fenced code blocks. It is a
VimL rule list. nvim-autopairs could consult the syntax tree and offered
fast-wrap, but this configuration enabled neither (`setup({})` plus one
backtick rule). The one behavior lost outside the rule list is the macro guard:
nvim-autopairs skipped pairing while a macro recorded or replayed
(`disable_in_macro`), which lexima does not do. lexima's rules are its own, and
this configuration adds none to them.

**vim-which-key for which-key.nvim.** Vim mappings carry no description, so
the popup labels come from `g:which_key_map` rather than from each mapping.
A new leader map without a dictionary entry appears unlabelled, where the old
`s:Map` passed a description to `nvim_set_keymap` and which-key.nvim read it.
The popup also waits for `timeoutlen`, set to 500 ms here, against
which-key.nvim's 200 ms delay.

**`:mksession` for persistence.nvim.** The `:Load` and `:Last` interface and
the per-directory idea survive; the storage does not. Sessions are written to
`~/.local/state/vim/sessions` on `VimLeavePre`, when a named buffer other than
a git commit, rebase or jj buffer is open, and gain a branch suffix when the
working directory is the top of a repository and the branch is not `main` or
`master`. The config also sets `sessionoptions-=options`, keeping editor
options out of the session file: Vim's default includes `options`, so without
that line a load would restore whatever `background` and other settings the
session recorded. As it stands, `:Load` cannot change editor options and so
never reverts daybreak's light or dark choice.

**fzf and fzf.vim for fzf-lua.** `:Files`, `:Rg`, `:Maps`, `:History` and
`:Helptags` cover the pickers the config used, with previews on all but
`:Maps`. `<leader>F` now
opens `:Files`; before it opened fzf-lua's picker menu, which exposed every
picker fzf-lua shipped — buffers, git commits, diagnostics, LSP references.
Those have no key now. There is no resume command, no devicons icons, and no
built-in previewer; fzf.vim's previews are shell scripts, and highlighting
them needs `bat` or another highlighter on `PATH`. fzf.vim also refuses to open
pickers below fzf 0.63 (its autoload sets `s:min_version`, although the README
still says 0.54), so the package version matters; [Vim plugins](vim-plugins.md)
covers it. `:Helptags` runs a Perl script, a dependency fzf-lua's help picker
did not need.

**startify for dashboard.** startify renders the six commands, a recent-files
list and a footer with the plugin count. Dashboard's week header, icons and
centered layout are gone. The command keys changed: `i` is startify's own
empty-buffer key where dashboard used `n`, and the command list puts the
session on `o` where dashboard used `s`.
[Shortcuts](shortcuts.md#the-startify-screen) lists the full screen.

**floaterm for toggleterm.** `<A-;>` toggles a terminal in normal and terminal
mode, and both plugins keep more than one terminal. The shape changed: the old
terminal was a horizontal split at toggleterm's 12-row default, with a shaded
background and a size persisted between toggles; the new one is a floating
window at 60% of the screen. `:ToggleTerm` is `:FloatermToggle`, and the split
sizing and shading are not reproduced.

**gitgutter and fugitive for gitsigns.** Signs, `]c`/`[c`, hunk stage and undo
(also over a visual range), the `ih` text object, buffer stage and reset,
blame, and diffs against the index (`:Gdiffsplit`) and HEAD (`:Gdiffsplit
HEAD`) all remain. What is gone: the inline annotation on the current line and
its toggle (`<leader>tb`), the inline hunk preview (`<leader>hi`), and hunk-level
unstaging. gitgutter can stage a hunk but not unstage one, so `<leader>hu` runs
`git restore --staged %` and unstages the whole buffer. `<leader>hb` opens
fugitive's `:Git blame` window instead of annotating the line, and `<leader>hp`
previews a hunk in a preview split instead of a floating popup. gitsigns
attached its maps buffer by buffer through `on_attach`; gitgutter's own maps
are switched off (`g:gitgutter_map_keys = 0`) and the same keys are global, so
they exist in every buffer.

**dirvish for oil.** `-` (or `:Dirvish`) opens the parent directory as a
listing whose lines are just paths. oil interpreted the buffer as a plan:
renaming a line renamed the file, deleting a line deleted it, and a new line
created a file when the buffer was written. dirvish never modifies the
filesystem, which is its stated design: the listing is an editable, reversible
view, and file operations are shell commands — `:e %name` to create a file,
`:!mkdir %name` for a directory, `:!rm` to delete, and `:Shdo` to write a shell
script from the listing followed by `Z!` to run it. So the old edit-and-write
workflow is gone and takes its confirmation-free convenience with it; the new
one is safe by construction and does the work through Vim's own `%` and `#`
names.

## Theme and appearance

`github-nvim-theme` emits Neovim highlight calls and its Vim entry points are
Lua shims, so it cannot load in Vim. The replacement is
`cormacrelf/vim-colors-github`, a VimL colorscheme named `github` that carries
a light and a dark palette in one file and picks between them from
`'background'`, which daybreak sets.

The old theme shipped eleven palette names. The configuration selected two:
`github_light` and `github_dark_dimmed`. Light is close to unchanged — a
`#ffffff` canvas either way. Dark is not: `github_dark_dimmed` painted on a
`#22272e` canvas with `#adbac7` text, and its softer contrast was the point of
the dimmed variant. What replaced it is GitHub's 2018 dark palette at
`#24292e` with `#fafbfc` text, verified from the colorscheme file and from a
running Vim. The dimmed palette is gone, along with the nine names the theme
offered and this configuration did not use: `github_dark`, `github_dark_default`,
`github_dark_high_contrast`, `github_dark_colorblind`, `github_dark_tritanopia`,
`github_light_default`, `github_light_high_contrast`, `github_light_colorblind`
and `github_light_tritanopia`. Nothing configured broke, but those palettes are
no longer available to choose, and the new colorscheme has two backgrounds
rather than a palette family. It also has no Treesitter, LSP or diagnostic
groups; Vim has no such highlighting for them to map onto.

## Daybreak

daybreak.nvim was a Lua plugin. It now carries a Vim implementation
(`autoload/daybreak.vim`, `plugin/daybreak.vim`, `autoload/daybreak/*.vim`),
and the Lua module only forwards setup options. Under Vim,
`plugin/daybreak.vim` calls `daybreak#setup()`, and the configuration only sets
`g:daybreak_light` and `g:daybreak_dark`, both `github` — the new colorscheme
has one name for both appearances. Detection stays inside the plugin: the macOS
appearance API, the Windows registry, the Linux desktop portal through `gdbus`,
and the clock as the last resort.

The pinned commit `e1f05db` is the Windows console fix. The `win32`/`win64`
check now precedes the desktop-session fallback, so a Windows console reads the
appearance from the registry instead of falling through to the clock, where a
console with no desktop session used to land. Nothing in this configuration
reads the registry or orders the backends itself, and the pin appears only in
`plug-snapshot.vim`.

One Vim limitation applies: live appearance updates need a Vim built with
`+job`. Without it the choice is applied once at startup. Neovim always had the
job API, so this only shows up under Vim.

## Keys

Five keys disappeared: `<leader>f<space>` (fzf-lua resume), `<leader>tb`
(toggle inline blame), `<leader>hi` (inline hunk preview), and dashboard's `n`
and `s` (startify uses `i` and `o`). Each is recorded with its reason in
[Shortcuts](shortcuts.md#deliberately-dropped); nothing here repeats the key
tables.

Keys that survived but now do something else:

- `<leader>F` opened fzf-lua's picker menu and opens `:Files`.
- `<leader>hu` unstaged a hunk through gitsigns and unstages the buffer.
- `<leader>hb` showed the current line's blame in a floating window and opens a
  `:Git blame` window.
- `<leader>tc` centers through goyo, with the tab and layout consequences
  above.

## Behavior and state

- A `~/.vimrc` makes Vim skip `defaults.vim`, which is what turns on filetype
  detection and indent detection, so the configuration enables `filetype on`
  and `filetype indent on` itself. It keeps `syntax off` and
  `filetype plugin off` as before. Without the detection lines every
  `FileType` autocmd would be dead: the indent rules, the markdown maps, spell
  in commits.
- The skipped `defaults.vim` also leaves Vim's other defaults different from
  Neovim's. The configuration therefore sets what the old setup relied on
  instead of inheriting it: `backspace`, `hidden`, `autoindent`, `mouse`,
  `whichwrap`, `nrformats`, `formatoptions`, `startofline`, `shortmess` and
  `wildoptions`.
- `guicursor` lost its terminal (`t:`) component, which Vim rejects. The cursor
  inside a terminal window now follows the terminal and terminfo, which matters
  for floaterm.
- Vim has no clipboard provider layer. The `+` register exists only on a
  `+clipboard` build, so `<leader>y`, `<leader>Y`, `<leader>p` and `<leader>P`
  are defined inside `if has('clipboard')`, and their which-key labels with
  them. No OSC 52 helper was added. On a `-clipboard` build — the Debian and
  Ubuntu `vim` package is one, and `vim --version` reports it — the keys stay
  free and the terminal's or tmux's copy path is the only one. tmux sets
  `set-clipboard on`, but Vim does not use it; that setting serves programs
  that emit OSC 52 themselves.
- Sessions save at `VimLeavePre` and restore with `:Load` and `:Last`, without
  editor options, as described above. Swap, undo and session files all live
  under `~/.local/state/vim`; backups under `~/.cache/vim`.

## What did not change

The plugins outside the table — securemodelines, vim-rsi, vim-repeat,
vim-matchup, vim-surround, undotree, vim-tmux-navigator and fugitive — are the
same, as are the markdown buffer maps, the filetype indent rules, the
trailing-whitespace strip on write, the 80-column centering width, the
`:Load`/`:Last` names, and no other tooling in the repository changed outside
the rows above. Every key not named above still does what
[Shortcuts](shortcuts.md) says.

## Verification

The migration was checked in a throwaway `HOME` holding only `.vimrc` and
`.vim/plug-snapshot.vim`: the run script installed 19 plugins at their pins and
exited 0, and Vim started with no messages. Startify rendered its commands,
recent files and "vim loaded 19 plugins"; which-key listed the groups;
`:Files`, `:Rg` and `:Maps` searched; gitgutter drew signs and staged a hunk;
dirvish listed a directory; floaterm opened; goyo centered at 80. Sessions were
written on exit, `:Load` and `:Last` restored them, a worktree session carried
its branch, and the session file contained no `set background`.

Repeating the theme and session checks on the current configuration gives dark
`#fafbfc` on `#24292e`, light `#24292e` on `#ffffff`, and a session file under
`~/.local/state/vim/sessions` with no options.
