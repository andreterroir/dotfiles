# Shortcuts

Every key this repository binds, by tool. Each tool section lists the keys the
configuration sets in a table, with a tool's related keys kept together;
plugin-owned keys are marked as such so a reader knows whether this repository
or the plugin decides them.

Conventions used below:

- `<leader>` is `Space`, set in `dot_vimrc` before any plugin loads.
- `<prefix>` is `C-Space` in tmux, set in `dot_tmux.conf.tmpl`.
- `<A-x>` is Alt+x, which Vim calls `<M-x>`.
- Modes are Vim's: `n` normal, `v` visual, `o` operator-pending, `i` insert,
  `c` command line, `t` terminal.

The same key can belong to more than one tool. `C-h`, `C-j`, `C-k` and `C-l`
move between Vim windows and between tmux panes, because vim-tmux-navigator
binds both sides: inside a pane running Vim they reach Vim, and anywhere else
they move panes. `C-r` is fzf history in the shell, redo in Vim normal mode,
and paste in Vim's command line. Focus decides which tool sees a key, so read
the section for the tool you are in.

## Vim

`dot_vimrc` (`~/.vimrc`) holds every global map, built with one `s:Map` helper
so that an empty mode string maps like `:map` (normal, visual, select and
operator-pending). It also maps `<leader>` itself to the which-key popup and
sets the global that defines the floaterm toggle. Plugin sections below cover
the keys a plugin chooses itself.

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
| `<leader>tc` | n, v, o | toggle centering (goyo, 80 columns) |
| `<leader>th` | n, v, o | toggle search highlighting |
| `<leader>tl` | n, v, o | toggle list chars |
| `<leader>ts` | n, v, o | toggle spellchecking |
| `<leader>tu` | n, v, o | toggle the undo tree |
| `<leader>tw` | n, v, o | toggle wrapping; linebreak follows it |
| `<leader>w` | n, v, o | write the buffer |

`<leader>F` and `<leader>ff` both open `:Files`; the capital is kept from the
earlier picker menu. Staging is per hunk, so `<leader>hu` unstages the whole
buffer rather than a hunk: gitgutter has no unstage-hunk action.

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
current directory and branch, `:Last` the most recently written one. startify
reaches them from the startup screen with `o` and `l`.

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

Keys the plugins define themselves. They change with a plugin upgrade, not with
`dot_vimrc`, except where the configuration overrides them.

| Key | Plugin | Mode | Action |
| --- | --- | --- | --- |
| `<A-;>` | vim-floaterm (via `g:floaterm_keymap_toggle`) | n, t | toggle the floating terminal |
| `-` | vim-dirvish | n | open the parent directory; `[count]-` goes up that many levels |
| `C-h` | vim-tmux-navigator | n, t | window left, or tmux pane left |
| `C-j` | vim-tmux-navigator | n, t | window down, or tmux pane down |
| `C-k` | vim-tmux-navigator | n, t | window up, or tmux pane up |
| `C-l` | vim-tmux-navigator | n, t | window right, or tmux pane right |
| `C-\` | vim-tmux-navigator | n | previous window or pane |
| `%` | vim-matchup | n, v, o | jump to the matching word; cycles at a closer |
| `g%` | vim-matchup | n, v, o | jump to the previous matching word |
| `[%` | vim-matchup | n, v, o | go to the outer opening word |
| `]%` | vim-matchup | n, v, o | go to the outer closing word |
| `z%` | vim-matchup | n, v, o | go inside the nearest block |
| `i%`, `a%` | vim-matchup | v, o | inside or around any block |
| `<C-G>%` | vim-matchup | i | jump to the matching delimiter, staying in insert mode |
| `<2-LeftMouse>` | vim-matchup | n | select the matching block |
| `ys` | vim-surround | n | add surroundings (`ysiw)` and friends) |
| `yss` | vim-surround | n | surround the whole line |
| `yS`, `ySs`, `ySS` | vim-surround | n | add surroundings on their own lines |
| `cs` | vim-surround | n | change surroundings |
| `cS` | vim-surround | n | change surroundings on their own lines |
| `ds` | vim-surround | n | delete surroundings |
| `S` | vim-surround | v | surround the selection |
| `gS` | vim-surround | v | surround the selection on its own lines |
| `<C-S>` | vim-surround | i | surround from insert mode |
| `<C-G>s`, `<C-G>S` | vim-surround | i | surround from insert mode (terminal-safe form) |

`<A-;>` is mapped in both normal and terminal mode; the terminal mapping first
leaves terminal-normal mode, so it toggles from inside the floating shell too.
It needs a terminal that sends Alt+; (Ghostty does).

Gitgutter's own maps are disabled with `g:gitgutter_map_keys = 0`, so the hunk
keys in `dot_vimrc` are the only ones; `]c` and `[c` fall back to Vim's
built-in change jumps inside a diff buffer. gitgutter still contributes the
`ih` text object. vim-fugitive adds `y<C-G>` (yank the object under the cursor)
and `<C-r><C-G>` on the command line; blame and diffs are on the leader keys
above.

### The dirvish listing

Buffer-local keys in a listing opened with `-` (or `:Dirvish`). `g?` in the
listing opens the plugin's own help with the complete set.

| Key | Action |
| --- | --- |
| `<CR>`, `i` | edit the entry |
| `o` | open the entry in a horizontal split |
| `a` | open the entry in a vertical split |
| `p` | preview the entry in the previous window, keeping focus in the listing |
| `q`, `gq` | close the listing |
| `~` | jump to the home directory |
| `cd` | change directory to the listing; with a count, only the window |
| `.` | run a shell command on the entry (`:!`) |
| `x` | add the selection to the argument list |
| `K` | show information about the entry |
| `O`, `I`, `A`, `P` | the same split, edit and preview actions for several marked entries |
| `<C-n>`, `<C-p>` | next or previous entry, previewing it |
| `Z!` | execute the listing as a shell script (how renames and deletes are applied) |

`-` is a global normal-mode map, so it also works from inside a listing.

### The startify screen

Vim's startup screen. The six commands are set in `dot_vimrc`; the rest are
startify's own buffer mappings.

| Key | Action |
| --- | --- |
| `f` | find a file (`:Files`) |
| `r` | recent files (`:History`) |
| `g` | find text (`:Rg`) |
| `c` | edit `~/.vimrc` |
| `o` | load the session for this directory and branch (`:Load`) |
| `l` | load the last session (`:Last`) |
| `e` | open an empty buffer |
| `i`, `<Insert>` | open an empty buffer and enter insert mode |
| `q` | quit the buffer, or Vim when no listed buffer is left |
| `b` | open an entry in the current window |
| `s` | open an entry in a split |
| `t` | open an entry in a tab |
| `v` | open an entry in a vertical split |
| `B`, `S`, `T`, `V` | the same, for several entries at once |
| `<CR>`, index key | open the entry under the cursor; the left-hand index is its key |

### The fzf pickers

| Key | Action |
| --- | --- |
| `<CR>` | open the selection |
| `C-t` | open in a new tab |
| `C-x` | open in a horizontal split |
| `C-v` | open in a vertical split |
| `C-e` | in `:History`, load the command on the command line for editing |

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

Insert and command-line maps from vim-rsi, which the configuration installs
without overriding:

| Key | Mode | Action |
| --- | --- | --- |
| `C-a` | i | jump to the first non-blank of the line |
| `C-a` | c | beginning of the command line |
| `C-b`, `C-f` | i, c | one character back or forward |
| `C-d` | i, c | delete the character under the cursor, or end of line |
| `C-e` | i | end of the line |
| `C-t` | c | transpose two characters |
| `C-u` | c | clear the line, keeping the head in a register |
| `C-y` | c | paste the last cleared head |
| `C-x C-a` | i, c | literal `C-a` |
| `M-b`, `M-f` | i, c | one word back or forward |
| `M-d` | i, c | delete a word |
| `M-n`, `M-p` | i, c | next or previous line |
| `M-BS`, `M-C-h` | i, c | delete the word before the cursor |

In the terminal, rsi reaches these through the escape sequences it sets for
`F29` to `F35`, because a plain Vim cannot map Meta keys directly.

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
desktops and `pbpaste` on macOS; no other target gets them. `C-l` and `C-\`
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

| Key | Plugin | Action |
| --- | --- | --- |
| `C-h`, `C-j`, `C-k`, `C-l` | vim-tmux-navigator | move to the pane in that direction, or leave the key to Vim when the pane runs Vim |
| `C-\` | vim-tmux-navigator | previous pane |
| `o` | tmux-open (copy mode) | open the selected path or URL in the system application |
| `C-o` | tmux-open (copy mode) | open the selected path in `$EDITOR` (`vim`) |

vim-tmux-navigator also binds those keys in copy mode, so they move panes while
scrolling. tmux-open's search-engine keys need `@open-*` options that this
configuration does not set, so it binds nothing else.

## Bash

The login shell is Bash (`run_onchange_set-up-default-shell.sh.tmpl`).
`dot_bashrc` holds the interactive setup. There is no zsh configuration in
this repository: no `.zshrc`, no `bindkey`, and nothing configures zsh, so
there are no zsh bindings to list here.

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

`dot_gitconfig.tmpl` sets two aliases and the mergetool; `git cleanup` is a
separate script on `PATH`:

| Command | Action |
| --- | --- |
| `git df` | `git diff --color-words` |
| `git continue` | commit with the message a failed commit left in `.git/COMMIT_EDITMSG`, reopening the editor |
| `git cleanup` | delete local branches merged into the current one; `git cleanup -n` prints instead of deleting (`dot_bin/executable_git-cleanup`) |
| `git mergetool` | open the conflict in Vim with `Gvdiffsplit!` |

The mergetool is Vim with fugitive's three-way diff, so its keys are fugitive's.
`core.editor` is `~/.bin/git-editor`, a wrapper that restores the message after
a failed commit — for example a missing signing key — and then starts Vim.

## Ghostty

`private_dot_config/ghostty/config.tmpl` binds the quick-terminal shortcut and
fullscreen:

| Key | Action |
| --- | --- |
| `Super+=` on Linux, `Cmd+=` on macOS | toggle the quick terminal (global, works from any app) |
| `F11` | toggle fullscreen |

## Keyboard

`~/.bin/swap_ctrl_caps` toggles the `ctrl:swapcaps` xkb option while preserving
the other options. It is a GNOME tool, installed on Linux only (`.chezmoiignore`
drops it on macOS), and it changes the layout rather than binding a key: after a
swap, every `C-` shortcut above moves to the physical Caps Lock position.

## Deliberately dropped

These keys existed before the migration from Neovim to Vim and were removed on
purpose. Do not add them back without deciding to reintroduce the behavior. The
migration and its wider losses are recorded in
[Vim migration](vim-migration.md).

| Key | What it was | Why it is gone |
| --- | --- | --- |
| `<leader>f<space>` | fzf-lua's picker resume | fzf.vim has no resume |
| `<leader>tb` | toggle inline line blame | the inline blame annotation is gone; `<leader>hb` opens a blame window instead |
| `<leader>hi` | inline hunk preview | no inline preview; `<leader>hp` previews in a split |
| dashboard `n` | new file | startify uses `i` |
| dashboard `s` | load session | startify uses `o`, and `:Load`/`:Last` remain |

Other shapes of the old setup are gone with their plugins, though the keys did
not move: no-neck-pain's window handling is replaced by goyo on `<leader>tc`,
oil.nvim's listing by dirvish on `-`, and persistence.nvim by `:Load`/`:Last`.
`<leader>hu` still exists but now unstages the buffer rather than a single hunk,
because gitgutter cannot unstage a hunk.

The clipboard maps were not dropped; they are conditional, as described above.
