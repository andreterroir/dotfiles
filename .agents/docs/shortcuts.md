# Shortcuts

Every key this repository binds or overrides, by tool. Plugin-owned keys are
pointed at rather than tabulated; each section names the help that holds them.

`<leader>` is `Space`, set in `dot_vimrc` before any plugin loads. `<prefix>` is
`C-Space` in tmux. `<A-x>` is Alt+x, which Vim calls `<M-x>`. Modes are Vim's:
`n` normal, `v` visual, `o` operator-pending, `i` insert, `c` command line,
`t` terminal.

The same key can belong to more than one tool: `C-h`, `C-j`, `C-k` and `C-l`
move between Vim windows and between tmux panes, and `C-\` goes to the previous
one, because vim-tmux-navigator binds both sides. `C-r` is fzf history in the
shell, redo in Vim normal mode, and paste in Vim's command line. Focus decides
which tool sees a key.

## Vim

`dot_vimrc` (`~/.vimrc`) holds every global map, built with one `s:Map` helper
so that an empty mode string maps like `:map` (normal, visual, select and
operator-pending). It also maps `<leader>` itself to the which-key popup and
sets the global that defines the floaterm toggle.

| Key | Mode | Action |
| --- | --- | --- |
| `<C-w>go` | n | close every other tab (`:tabonly`) |
| `]c` | n | next git hunk; inside a diff buffer, the built-in change jump |
| `]q` | n | next quickfix entry |
| `[c` | n | previous git hunk; inside a diff buffer, the built-in change jump |
| `[q` | n | previous quickfix entry |
| `<leader>-` | n, v, o | split horizontally |
| `<leader>\` | n, v, o | split vertically |
| `<leader>;` | n, v, o | enter the command line (saves the pinky) |
| `<leader>F` | n | files (`:Files`) |
| `<leader>ff` | n | files (`:Files`) |
| `<leader>fg` | n | grep the repository (`:Rg`) |
| `<leader>fh` | n | help tags (`:Helptags`) |
| `<leader>fk` | n | key mappings (`:Maps`) |
| `<leader>fr` | n | recent files (`:History`) |
| `<leader>fs` | n | grep the WORD under the cursor (`:Rg <C-r><C-a>`) |
| `<leader>hs` | n, v | stage hunk |
| `<leader>hr` | n, v | undo hunk |
| `<leader>hS` | n | stage the whole buffer (`:Git add %`) |
| `<leader>hu` | n | unstage the whole buffer (`:Git restore --staged %`) |
| `<leader>hR` | n | discard the buffer's changes (`:Git restore %`) |
| `<leader>hp` | n | preview hunk |
| `<leader>hb` | n | blame in a `:Git blame` window |
| `<leader>hd` | n | diff against the index (`:Gdiffsplit`) |
| `<leader>hD` | n | diff against HEAD (`:Gdiffsplit HEAD`) |
| `ih` | o, v | hunk text object |
| `<leader>q` | n, v, o | quit all windows and Vim, with confirmation |
| `<leader>tc` | n, v, o | toggle centering (goyo, 80 columns, in a new tab) |
| `<leader>th` | n, v, o | toggle search highlighting |
| `<leader>tl` | n, v, o | toggle list chars |
| `<leader>ts` | n, v, o | toggle spellchecking |
| `<leader>tu` | n, v, o | toggle the undo tree |
| `<leader>tw` | n, v, o | toggle wrapping; linebreak follows it |
| `<leader>w` | n, v, o | write the buffer |

`<leader>F` and `<leader>ff` both open `:Files`. Staging is per hunk, so
`<leader>hu` unstages the whole buffer rather than a hunk: gitgutter has no
unstage-hunk action.

The clipboard maps exist only when Vim reports `+clipboard`, and the same
block in `dot_vimrc` leaves them out of `g:which_key_map`. On a `-clipboard`
build the keys are not defined at all, and the terminal's own copy and paste —
tmux copy mode, or the terminal's selection — is the only path. That gap is
deliberate: no OSC 52 helper fills it. Check a build with
`vim --version | grep clipboard`.

| Key | Mode | Action |
| --- | --- | --- |
| `<leader>y` | n, v | yank to the system clipboard (`"+y`) |
| `<leader>Y` | n | yank to the end of the line (`"+y$`) |
| `<leader>p` | n, v | paste from the system clipboard (`"+p`) |
| `<leader>P` | n | paste before the cursor (`"+P`) |

Sessions have commands rather than keys: `:Load` restores the session for the
current directory and branch, `:Last` the most recently written one. A session
is written on exit, when a named buffer is open, and holds no editor options.

`<leader>` alone opens the which-key popup in normal and visual mode, after
`timeoutlen` (500 ms). vim-which-key cannot read Vim's mapping descriptions, so
the labels come from `g:which_key_map` in `dot_vimrc`:

| Prefix | Label |
| --- | --- |
| `<leader>t` | `+toggle`: h search highlighting, s spellchecking, l list chars, w wrapping, c centering, u undo tree |
| `<leader>f` | `+find`: f files, g grep, s word under cursor, k key mappings, r recent files, h help |
| `<leader>h` | `+hunk`: s stage hunk, r reset hunk, S stage buffer, R reset buffer, u unstage buffer, p preview hunk, b blame, d diff index, D diff HEAD |
| `<leader>F` | files |
| `<leader>-` | split horizontally |
| `<leader>\` | split vertically |
| `<leader>;` | command-line |
| `<leader>w` | write buffer |
| `<leader>q` | quit with confirmation |
| `<leader>y`, `<leader>Y`, `<leader>p`, `<leader>P` | clipboard labels, only on `+clipboard` builds |

A new leader map without an entry here appears unlabelled in the popup.

`<A-;>` comes from vim-floaterm: `dot_vimrc` assigns
`g:floaterm_keymap_toggle`, and the plugin maps it in normal and terminal mode,
so it also toggles from inside the floating shell. It needs a terminal that
sends Alt+; (Ghostty does). Gitgutter's own maps are switched off with
`g:gitgutter_map_keys = 0`.

Other keys come from their plugins: `-` opens the parent directory as a
vim-dirvish listing (`:help dirvish`), startify's screen maps files, recent
files, find text, the vimrc, and the two sessions (`:help startify`), fzf.vim's
pickers open, split, or tab (`:help fzf-vim`), vim-rsi's insert and
command-line maps are unchanged (`:help rsi`), and `:help matchup`,
`:help surround`, `:help tmux-navigator`, `:help fugitive` cover the rest.

Markdown buffers swap the wrapped-line motions, buffer-locally, in normal and
visual mode: `j` and `k` move by screen line (`gj`, `gk`), and `gj` and `gk`
move by buffer line (`j`, `k`).

`~/.vim/init.local.vim` is sourced last, outside the repository, so anything
there wins over these maps, and nothing here can document those keys.

## tmux

The prefix is `C-Space` instead of tmux's `C-b`. Windows and panes are numbered
from 1. Mouse mode and focus events are on, and the copy-mode table uses vi
keys.

| Key | Action |
| --- | --- |
| `<prefix>;` | command prompt; this displaces tmux's `;` (last pane) |
| `<prefix>-` | split down, in the pane's current directory |
| `<prefix>\` | split right, in the pane's current directory |
| `<prefix>*` | paste the primary selection into the pane |
| `<prefix>+` | paste the clipboard into the pane |
| `<prefix>C-l` | send `C-l` to the pane (clears the screen) |
| `<prefix>C-\` | send `C-\` to the pane |

`<prefix>*` and `<prefix>+` read the selection with `wl-paste` on Linux
desktops; no other target gets them. `C-l` and `C-\` are sent through because
vim-tmux-navigator takes the unprefixed keys. tmux's own bindings are unchanged
around these.

| Key | Copy mode |
| --- | --- |
| `v` | start a selection |
| `C-v` | toggle rectangle selection |
| `y` | copy the selection and leave copy mode |
| `Y` | copy to the end of the line and leave |
| `C-y` | copy the line and leave |
| `Enter` | copy the selection to `wl-copy` and leave (Linux desktops only) |

`set-clipboard on` lets programs that emit OSC 52 write the clipboard through
tmux; Vim does not use that path.

tmux-open adds copy-mode `o` and `C-o` to open the selection in the system
application or in `$EDITOR`, and its search-engine keys stay unbound because
this configuration sets no `@open-*` options. vim-tmux-navigator's `C-h`,
`C-j`, `C-k`, `C-l` and `C-\` bind in copy mode too.

## Bash

`dot_bashrc` holds the interactive setup for Bash, the login shell the Linux
targets default to. There is no zsh configuration in this repository.

| Key | Action |
| --- | --- |
| `C-s` | forward history search; `stty -ixon` disables the terminal's stop-output so readline receives it |
| `Tab` | completion, from bash-completion plus chezmoi, cargo, rustup and Amp completions |
| `C-t` | fzf: paste the selected path onto the command line |
| `C-r` | fzf: search history |
| `M-c` | fzf: change directory |
| `**<Tab>` | fzf: completion trigger |

The fzf keys come from `fzf --bash`, or from the packaged scripts on older
packages; `dot_bashrc` sources them but does not change them.

Aliases and functions are command shortcuts rather than keys:

| Shortcut | Expands to / does |
| --- | --- |
| `ls` | `ls --classify --color=auto` |
| `grep` | `grep --color=auto` |
| `cz` | `chezmoi` |
| `g` | `git` |
| `python` | `python3` |
| `v`, `vi` | `vim` |
| `t` | `tmux attach` or `tmux new` |
| `fd` | `fdfind`, where that is the packaged name |
| `bytes` | bytes `[START, END)` of stdin, counting from 0, so `bytes 4 10` is bytes 4 to 9 |

`bytes` is a function rather than an alias: it checks the two numbers itself and
answers a bad range with a usage line instead of `head`'s. It counts bytes
across the whole stream, unlike `cut -b`, which restarts the range on every line.

## git

`dot_gitconfig.tmpl` sets one alias and the mergetool; `git cleanup` is a
separate script on `PATH`:

| Command | Action |
| --- | --- |
| `git df` | `git diff --color-words` |
| `git cleanup` | delete local branches merged into the current one; `git cleanup -n` prints instead of deleting (`dot_bin/executable_git-cleanup`) |
| `git mergetool` | open the conflict in Vim with `Gvdiffsplit!` |

The mergetool is Vim with fugitive's three-way diff, so its keys are fugitive's.
`core.editor` is `~/.bin/git-editor`, a wrapper that restores the message after
a failed commit — for example a missing signing key — and then starts Vim.

## Ghostty

`private_dot_config/ghostty/config.tmpl` binds fullscreen:

| Key | Action |
| --- | --- |
| `F11` | toggle fullscreen |

Ghostty's quick terminal needs the `wlr-layer-shell` protocol, which GNOME does
not implement, so the dropdown is ddterm's.

## Dropdown terminal

`run_onchange_install-linux-packages.sh.tmpl` installs ddterm on Fedora
desktops; `run_onchange_set-up-gnome-shell-extensions.sh.tmpl` enables it and
sets its hotkey:

| Key | Action |
| --- | --- |
| `Super+\` | toggle the dropdown terminal (global, works from any app) |

`Super+\` replaces ddterm's `F12` default, which would take F12 away from every
application, browsers' DevTools included.

## Window management

`run_onchange_set-up-gnome-window-shortcuts.sh.tmpl` mirrors the Rectangle
layout, whose chords are Control+Command plus a home-row letter; Command maps
to Super, so the letter carries the muscle memory over. GNOME's own
`Super+arrow` tiling stays bound alongside.

| Key | Action |
| --- | --- |
| `Ctrl+Super+H` | left half; press again to untile |
| `Ctrl+Super+L` | right half; press again to untile |
| `Ctrl+Super+J`, `Ctrl+Super+M` | center, at the window's current size |
| `Ctrl+Super+K` | maximize |
| `Ctrl+Super+U` | restore a maximized or tiled window to its previous geometry |
| `Super+M`, `Super+H` | minimize |
| `Ctrl+Super+F` | toggle fullscreen |

`Ctrl+Super+F` is the fullscreen chord rather than a Rectangle binding, so it
toggles fullscreen instead of maximizing; mutter applies the state itself, and
declines dialogs and fixed-size windows. Close stays `Alt+F4`, and quitting has
no chord: the window manager can ask a window to close, but no GNOME schema
exposes a quit action. `Super+M` came from the message tray, which keeps
`Super+V` and gives M up rather than report a duplicate accelerator.

## Keyboard

`~/.bin/swap_ctrl_caps` toggles the `ctrl:swapcaps` xkb option while preserving
the other options. It is managed only on GNOME desktops, and it changes the
layout: after a swap, every `C-` shortcut above moves to the physical Caps Lock
position.

## Deliberately dropped

Do not add these back without deciding to reintroduce the behaviour.

| Key | What it was | Why it is gone |
| --- | --- | --- |
| `<leader>f<space>` | fzf-lua's picker resume | fzf.vim has no resume |
| `<leader>tb` | toggle inline line blame | the annotation is gone; `<leader>hb` opens a blame window |
| `<leader>hi` | inline hunk preview | `<leader>hp` previews in a split |
| `Super+=` | Ghostty's quick terminal | GNOME has no `wlr-layer-shell`, so the window never appeared; ddterm's dropdown moved to `Super+\` |

Window centering is goyo on `<leader>tc`, directory listings are dirvish on
`-`, and sessions are `:Load`/`:Last`; the plugins that did those jobs before
are gone, not their keys.
