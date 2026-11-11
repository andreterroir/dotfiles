# Shortcuts

Every key this repository binds or overrides, by tool. Plugin-owned keys are
pointed at rather than tabulated; each section names the help that holds them.

Conventions used below:

- `<leader>` is `Space`, set in `dot_vimrc` before any plugin loads.
- `<prefix>` is `C-Space` in tmux, set in `dot_tmux.conf.tmpl`.
- `<A-x>` is Alt+x, which Vim calls `<M-x>`.
- Modes are Vim's: `n` normal, `v` visual, `o` operator-pending, `i` insert,
  `c` command line, `t` terminal.

The same key can belong to more than one tool. `C-h`, `C-j`, `C-k` and `C-l`
move between Vim windows and between tmux panes, and `C-\` goes to the previous
one, because vim-tmux-navigator binds both sides: inside a pane running Vim
they reach Vim, and anywhere else they move panes. `C-r` is fzf history in the
shell, redo in Vim normal mode, and paste in Vim's command line. Focus decides
which tool sees a key, so read the section for the tool you are in.

## Vim

`dot_vimrc` (`~/.vimrc`) holds every global map, built with one `s:Map` helper
so that an empty mode string maps like `:map` (normal, visual, select and
operator-pending). It also maps `<leader>` itself to the which-key popup and
sets the global that defines the floaterm toggle.

### Maps set in `dot_vimrc`

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

### Clipboard maps are conditional

| Key | Mode | Action |
| --- | --- | --- |
| `<leader>y` | n, v | yank to the system clipboard (`"+y`) |
| `<leader>Y` | n | yank to the end of the line (`"+y$`) |
| `<leader>p` | n, v | paste from the system clipboard (`"+p`) |
| `<leader>P` | n | paste before the cursor (`"+P`) |

These exist only when Vim reports `+clipboard`; on a `-clipboard` build the
keys are not defined at all, and the same block in `dot_vimrc` also leaves them
out of `g:which_key_map`, so which-key shows no clipboard entries. Check a
build with `vim --version | grep clipboard`.

The gaps are deliberate: the setup follows the editor build rather than adding
a workaround. There is no OSC 52 helper and no attempt to make clipboard
bindings work on every machine, so a `-clipboard` Vim uses the terminal's own
copy and paste — tmux copy mode, or the terminal's selection — instead. Do not
read an absent `<leader>y` as a bug, and do not add a helper to fill it.

### Session commands

Sessions have commands rather than keys: `:Load` restores the session for the
current directory and branch, `:Last` the most recently written one. A session
is written on exit, when a named buffer is open, and holds no editor options,
so loading one never changes them.

### which-key

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

### Plugin keys

`<A-;>` comes from vim-floaterm: `dot_vimrc` assigns
`g:floaterm_keymap_toggle`, and the plugin maps it in normal and terminal
mode, so it also toggles from inside the floating shell. It needs a terminal
that sends Alt+; (Ghostty does). Gitgutter's own maps are switched off with
`g:gitgutter_map_keys = 0`, so the hunk keys above are the only ones. Every
other plugin key belongs to the plugin and is in its help: `:help dirvish`,
`:help matchup`, `:help surround`, `:help tmux-navigator`, `:help fugitive`.

### The dirvish listing

`-` opens the parent directory as a listing, and `[count]-` goes up that many
levels. The listing's buffer maps are vim-dirvish's; `:help dirvish` lists
them.

### The startify screen

`dot_vimrc` fills startify's command list: `f` files, `r` recent files, `g`
find text, `c` the vimrc, `o` load session, `l` last session. The screen's
remaining buffer maps are startify's; `:help startify` lists them.

### The fzf pickers

The picker maps — open, split, tab, and `C-e` to pull a history entry onto the
command line — are fzf.vim's; `:help fzf-vim` lists them.

`<leader>fs` passes the WORD under the cursor, while the which-key label for it
says "word under cursor".

### Markdown buffers

Markdown buffers swap the wrapped-line motions, in normal and visual mode:

| Key | Action |
| --- | --- |
| `j`, `k` | move by screen line (`gj`, `gk`) |
| `gj`, `gk` | move by buffer line (`j`, `k`) |

These are buffer-local, defined by `s:Markdown()`; nothing else gets them.

### Emacs-style editing (vim-rsi)

vim-rsi installs its insert and command-line maps unchanged; `:help rsi` lists
them.

### Per-machine overrides

`~/.vim/init.local.vim` is sourced last, outside the repository, so anything
there wins over the maps above; `dot_vimrc` defines no content for it. Nothing
in this repository can document those keys — read the file on the machine.

## tmux

### Prefix and tables

The prefix is `C-Space` instead of tmux's `C-b`. Windows and panes are
numbered from 1. Mouse mode and focus events are on, and the copy-mode table
uses vi keys.

### Prefix bindings set by this configuration

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
desktops; no other target gets them. `C-l` and `C-\`
are sent through because vim-tmux-navigator takes the unprefixed keys.

tmux's own bindings are unchanged around these: `<prefix>"` and `<prefix>%`
still split, and `<prefix>z` (zoom), `<prefix>x` (kill pane), `<prefix>c` (new
window), `<prefix>,` (rename window), `<prefix>[` (copy mode), `<prefix>]`
(paste buffer), `<prefix>&` (kill window) and `<prefix>d` (detach) all still
work.

### Copy mode (vi keys)

| Key | Action |
| --- | --- |
| `v` | start a selection |
| `C-v` | toggle rectangle selection |
| `y` | copy the selection and leave copy mode |
| `Y` | copy to the end of the line and leave |
| `C-y` | copy the line and leave |
| `Enter` | copy the selection to `wl-copy` and leave (Linux desktops only) |

`set-clipboard on` lets programs that emit OSC 52 write the clipboard through
tmux. Vim does not use that path; see the conditional clipboard maps above.

### Keys from tmux plugins

tmux-open adds copy mode `o` and `C-o` to open the selection in the system
application or in `$EDITOR`, and its search-engine keys stay unbound because
this configuration sets no `@open-*` options; `list-keys -T copy-mode-vi` shows
the table. vim-tmux-navigator's `C-h`, `C-j`, `C-k`, `C-l` and `C-\` bind there
too.

## Bash

`dot_bashrc` holds the interactive setup for Bash, the login shell the Linux
targets default to. There is no zsh configuration in this repository: no
`.zshrc`, no `bindkey`, and nothing configures zsh, so there are no zsh
bindings to list here.

| Key | Action |
| --- | --- |
| `C-s` | forward history search; `stty -ixon` disables the terminal's stop-output so readline receives it |
| `Tab` | completion, from bash-completion plus chezmoi, cargo, rustup and Amp completions |
| `C-t` | fzf: paste the selected path onto the command line |
| `C-r` | fzf: search history |
| `M-c` | fzf: change directory |
| `**<Tab>` | fzf: completion trigger |

The fzf keys come from `fzf --bash` (or, on older packages, the packaged
`key-bindings.bash`); `dot_bashrc` sources them but does not change them.

Aliases are command shortcuts rather than keys:

| Alias | Expands to |
| --- | --- |
| `ls` | `ls --classify --color=auto` |
| `grep` | `grep --color=always` |
| `cz` | `chezmoi` |
| `g` | `git` |
| `python` | `python3` |
| `v`, `vi` | `vim` |
| `t` | `tmux attach` or `tmux new` |
| `fd` | `fdfind`, where that is the packaged name |

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
a failed commit — for example a missing signing key — and then starts Vim, so a
plain `git commit` retries with the message intact.

## Ghostty

`private_dot_config/ghostty/config.tmpl` binds fullscreen:

| Key | Action |
| --- | --- |
| `F11` | toggle fullscreen |

Ghostty's quick terminal needs the `wlr-layer-shell` protocol, which GNOME does
not implement, so the dropdown is ddterm's instead.

## Dropdown terminal

`run_onchange_install-linux-packages.sh.tmpl` installs ddterm on Fedora
desktops; `run_onchange_set-up-gnome-shell-extensions.sh.tmpl` enables it and
sets its hotkey:

| Key | Action |
| --- | --- |
| `Super+=` | toggle the dropdown terminal (global, works from any app) |

`Super+=` replaces ddterm's `F12` default, which would take F12 away from every
application, browsers' DevTools included.

## Window management

`run_onchange_set-up-gnome-window-shortcuts.sh.tmpl` mirrors the Rectangle
setup on macOS, which binds Control+Command plus a home-row letter. Command
maps to Super, so the letter alone carries the muscle memory over, and GNOME's
own `Super+arrow` tiling stays bound alongside:

| Key | Action |
| --- | --- |
| `Ctrl+Super+H` | left half; press again to untile |
| `Ctrl+Super+L` | right half; press again to untile |
| `Ctrl+Super+J`, `Ctrl+Super+M` | center, at the window's current size |
| `Ctrl+Super+K` | maximize |
| `Ctrl+Super+U` | restore a maximized or tiled window to its previous geometry |
| `Super+H` | minimize; GNOME's own key, left as it ships |
| `Ctrl+Super+F` | toggle fullscreen |
| `Super+Left`, `Super+Right`, `Super+Up`, `Super+Down` | GNOME's own halves, maximize and restore |

`Ctrl+Super+F` is macOS's fullscreen chord rather than a Rectangle binding, so
it toggles fullscreen rather than maximizing, keeping the mac's meaning. Mutter
applies the state itself, so the app's own fullscreen support does not matter,
though it declines dialogs and fixed-size windows, where the key does nothing.
Maximize stays on `Ctrl+Super+K`.

Closing and quitting stay where they were. `Cmd+W` would be the bare `Super+W`
here, not the `Ctrl+Super` cluster the Rectangle chords use, so close remains
`Alt+F4`; and `Cmd+Q` has no counterpart at all, because the window manager can
ask one window to close but cannot quit an application, and no GNOME schema
exposes a quit action.

`Cmd+M` reaches GNOME's own `Super+H`, because `<Super>M` is not free:
`org.gnome.shell.keybindings toggle-message-tray` already holds `<Super>V` and
`<Super>M`. A duplicated accelerator has no clean precedence in GNOME — either
the tray stops opening or both actions fire — so `minimize` is left alone and
`Super+M` still opens the tray. Freeing M would mean trimming the tray to
`<Super>V` first, which is a change to a built-in binding rather than an
addition.

macOS's `Cmd+H` hides a whole application, which GNOME cannot do, and
`Ctrl+Super+H` stays left half, the chord Rectangle gives that action.

Rectangle's Center Half (`Cmd+Ctrl+M`) centers on the same action as
`Ctrl+Super+J`, but the size differs: Rectangle also resizes to half the screen,
while no GNOME action centers a window at a fraction — the halves resize but
anchor to an edge, and `move-to-center` keeps the current size. Matching the size
would need a grid-tiling extension such as gTile, with its own grab layer and
shell-version coupling.

Everything else in the Rectangle set that is not a window position — todo-list
toggles, snap areas, arrow defaults it clears — has no keybinding counterpart
here.

## Keyboard

`~/.bin/swap_ctrl_caps` toggles the `ctrl:swapcaps` xkb option while preserving
the other options. It is a GNOME tool, managed only on GNOME desktops
(`.chezmoiignore` drops it otherwise), and it changes the layout rather than
binding a key: after a swap, every `C-` shortcut above moves to the physical
Caps Lock position.

## Deliberately dropped

These keys came from plugins the configuration no longer installs and were not
replaced. Do not add them back without deciding to reintroduce the behavior.

| Key | What it was | Why it is gone |
| --- | --- | --- |
| `<leader>f<space>` | fzf-lua's picker resume | fzf.vim has no resume |
| `<leader>tb` | toggle inline line blame | the inline blame annotation is gone; `<leader>hb` opens a blame window instead |
| `<leader>hi` | inline hunk preview | no inline preview; `<leader>hp` previews in a split |
| dashboard `n` | new file | startify uses `i` |
| dashboard `s` | load session | startify uses `o`, and `:Load`/`:Last` remain |
| `Super+=` | Ghostty's quick terminal | GNOME has no `wlr-layer-shell` protocol, so the window never appeared; ddterm's dropdown uses the key now |
| `Cmd+=` | Ghostty quick terminal on macOS | macOS is no longer a supported target |

Window centering is goyo on `<leader>tc`, directory listings are dirvish on
`-`, and sessions are `:Load`/`:Last`; the plugins that did those jobs before
are gone, not their keys. `<leader>hu` still exists but unstages the buffer
rather than a single hunk, because gitgutter cannot unstage a hunk.
