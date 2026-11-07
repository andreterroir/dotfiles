" -------------
" -- plugins --
" -------------

" bootstrap vim-plug, pinned so every machine gets the same manager
let s:plug_commit = '4c4e56b5f7384369927a075804b6a17de7644edd'
let s:plugpath = stdpath('data') . '/site/autoload/plug.vim'
if !filereadable(s:plugpath)
  call system(['curl', '-sfLo', s:plugpath, '--create-dirs',
        \ 'https://raw.githubusercontent.com/junegunn/vim-plug/' . s:plug_commit . '/plug.vim'])
  " neovim caches runtimepath lookups at startup, so a file written during
  " this run is not found by autoload until it is sourced
  execute 'source ' . fnameescape(s:plugpath)
endif

" map leader before any plugins define their mappings
let mapleader = ' '

call plug#begin('~/.vim/plugged')

" colorscheme; one file, light and dark picked by 'background'
Plug 'cormacrelf/vim-colors-github'
" center the focused buffer
Plug 'shortcuts/no-neck-pain.nvim'
" restrict allowed modeline options
Plug 'ypcrts/securemodelines'
" readline style editing keybindings
Plug 'tpope/vim-rsi'
" repeat plugin commands with dot
Plug 'tpope/vim-repeat'
" highlight and navigate matching text
Plug 'andymass/vim-matchup'
" add, change and delete surrounding characters
Plug 'tpope/vim-surround'
" insert and step over matching characters
Plug 'cohama/lexima.vim'
" keymap discovery
Plug 'liuchengxu/vim-which-key'
" persistent branching undo history
Plug 'mbbill/undotree'
" preserve last session per directory
Plug 'folke/persistence.nvim'
" navigation
Plug 'christoomey/vim-tmux-navigator'
" search
Plug 'junegunn/fzf'
Plug 'junegunn/fzf.vim'
" startup screen
Plug 'mhinz/vim-startify'
" persistent fast access terminal
Plug 'voldikss/vim-floaterm'
" Git interface
Plug 'tpope/vim-fugitive'
" inline Git interface
Plug 'lewis6991/gitsigns.nvim'
" file manager
Plug 'stevearc/oil.nvim'

call plug#end()

" vim.keymap.set made maps non-remappable; nvim_set_keymap defaults to
" remappable, so noremap is passed explicitly, plus the old descriptions
function! s:Map(mode, lhs, rhs, ...) abort
  call nvim_set_keymap(a:mode, a:lhs, a:rhs, a:0 ? #{noremap: v:true, desc: a:1} : #{noremap: v:true})
endfunction

function! s:BufMap(bufnr, mode, lhs, rhs, ...) abort
  call nvim_buf_set_keymap(a:bufnr, a:mode, a:lhs, a:rhs, a:0 ? #{noremap: v:true, desc: a:1} : #{noremap: v:true})
endfunction

" gitsigns maps keys per buffer and only offers a Lua hook, so it hands every
" buffer it attaches to here
function! GitsignsMaps(bufnr) abort
  " in diff mode ]c/[c keep the built-in jumps between diff hunks
  call s:BufMap(a:bufnr, 'n', ']c', '<cmd>execute &diff ? "normal! ]c" : "Gitsigns nav_hunk next"<CR>')
  call s:BufMap(a:bufnr, 'n', '[c', '<cmd>execute &diff ? "normal! [c" : "Gitsigns nav_hunk prev"<CR>')

  " actions
  for mode in ['n', 'v']
    call s:BufMap(a:bufnr, mode, '<leader>hs', '<cmd>Gitsigns stage_hunk<CR>')
    call s:BufMap(a:bufnr, mode, '<leader>hr', '<cmd>Gitsigns reset_hunk<CR>')
  endfor
  call s:BufMap(a:bufnr, 'n', '<leader>hS', '<cmd>Gitsigns stage_buffer<CR>')
  " stage_hunk on a staged hunk unstages it (undo_stage_hunk is deprecated)
  call s:BufMap(a:bufnr, 'n', '<leader>hu', '<cmd>Gitsigns stage_hunk<CR>')
  call s:BufMap(a:bufnr, 'n', '<leader>hR', '<cmd>Gitsigns reset_buffer<CR>')
  call s:BufMap(a:bufnr, 'n', '<leader>hp', '<cmd>Gitsigns preview_hunk<CR>')
  call s:BufMap(a:bufnr, 'n', '<leader>hb', '<cmd>Gitsigns blame_line full=true<CR>')
  call s:BufMap(a:bufnr, 'n', '<leader>tb', '<cmd>Gitsigns toggle_current_line_blame<CR>', '[t]oggle [b]lame')
  call s:BufMap(a:bufnr, 'n', '<leader>hd', '<cmd>Gitsigns diffthis<CR>')
  call s:BufMap(a:bufnr, 'n', '<leader>hD', '<cmd>Gitsigns diffthis ~<CR>')
  call s:BufMap(a:bufnr, 'n', '<leader>hi', '<cmd>Gitsigns preview_hunk_inline<CR>')

  " text object
  for mode in ['o', 'x']
    call s:BufMap(a:bufnr, mode, 'ih', ':<C-U>Gitsigns select_hunk<CR>')
  endfor
endfunction

let g:floaterm_keymap_toggle = '<A-;>'

" vim-plug leaves uninstalled plugins off the runtimepath, so configuring them
" before :PlugInstall has run would abort this file on a new machine
let s:missing = filter(copy(g:plugs), '!isdirectory(v:val.dir)')

if empty(s:missing)
  try
    " daybreak will drive this once its Vim port is available
    set background=dark
    colorscheme github
    lua require('no-neck-pain').setup({ width = 80 })
    lua require('persistence').setup({})
    command! Load lua require('persistence').load()
    command! Last lua require('persistence').load({ last = true })
    lua require('gitsigns').setup({ on_attach = function(bufnr) vim.fn.GitsignsMaps(bufnr) end })
    lua require('oil').setup()
    let g:startify_custom_header = []
    let g:startify_lists = [
          \ {'type': 'commands', 'header': ['   Commands']},
          \ {'type': 'files', 'header': ['   Recent']},
          \ ]
    let g:startify_commands = [
          \ {'f': ['Find file', 'Files']},
          \ {'r': ['Recent files', 'History']},
          \ {'g': ['Find text', 'Rg']},
          \ {'c': ['Config', 'edit ~/.config/nvim/init.vim']},
          \ {'o': ['Load session', 'Load']},
          \ {'l': ['Last session', 'Last']},
          \ ]
    let g:startify_custom_footer = ['', 'vim loaded ' . len(g:plugs) . ' plugins']
  catch
    echohl ErrorMsg
    echomsg 'nvim: plugin setup failed: ' . v:exception
    echohl None
  endtry
else
  echohl WarningMsg
  echomsg printf('vim-plug: %d plugin(s) missing, run :PlugInstall and restart', len(s:missing))
  echohl None
endif

" -------------
" -- options --
" -------------

" blinking block cursor for insert, replace, command and terminal modes
set guicursor=i-r-c-ci-cr-t:block-blinkwait300-blinkoff150-blinkon150

syntax off
filetype plugin off
" enable true color support
set termguicolors

" render tabs as 4 spaces
set tabstop=4
" insert 4 spaces for a tab
set softtabstop=4
" insert 4 spaces for an indent
set shiftwidth=4
" replace each 8 spaces by a tab
set noexpandtab

" use space as vertical split character
let &fillchars = 'vert: '
" show trailing characters, tabs and non-breakable spaces
set list
let &listchars = 'tab:  ,trail:·,nbsp:⍽,extends:»,precedes:«'
" indent wrapped lines
set breakindent
" show marker for wrapped lines
let &showbreak = '↳ '
" recognize bullet point as well as numbered lists: optional whitespace
" followed either by a digit with an optional ]/:/./)/} or -/*/+
" with at least one space after
let &formatlistpat = '^\s*\(\d\+[\]:.)}]*\|[-\*+]\)\s\+'
" before indented text; shift lists by width of the prefix pattern (above)
set breakindentopt=sbr,list:-1
" in the number column
set cpoptions+=n
" conceal syntax (e.g. Markdown), but not completely (highlight code block marks)
set conceallevel=1
" display line numbers
set number
" highlight the line number for the current line
set cursorline
set cursorlineopt=number
" always display the line info column to avoid jumping
set signcolumn=yes
" open folds by default
set foldlevelstart=99

" do not highlight search results by default
set nohlsearch
" autocomplete to the longest commons string and than cycle through the
" alternatives
set wildmode=longest:full,full
" how long a prefix waits before which-key opens
set timeoutlen=500

" keep backup if file is overwritten
set backup
" make a copy to create a backup, overwrite the original file in place
" this preserves the file creation timestamp (birthtime)
set backupcopy=yes
" create backupdir if it doesn't exist
let s:backup_dir = expand('~/.cache/nvim/backup')
if !isdirectory(s:backup_dir)
  call mkdir(s:backup_dir, 'p')
endif
" save all backups in one place rather than in .
let &backupdir = s:backup_dir
" persist undo history
set undofile

" ------------
" -- keymap --
" ------------

" an empty mode is an equivalent of :map, which applies to
" normal, visual, select and operator-pending mode

" toggles
call s:Map('', '<leader>th', '<cmd>set hlsearch!<CR>', '[t]oggle search [h]ighlighting')
call s:Map('', '<leader>ts', '<cmd>set spell!<CR>', '[t]oggle [s]pellchecking')
call s:Map('', '<leader>tl', '<cmd>set list!<CR>', '[t]oggle [l]ist chars')
call s:Map('', '<leader>tw', '<cmd>let &wrap = !&wrap<Bar>let &linebreak = &wrap<CR>', '[t]oggle [w]rapping')
call s:Map('', '<leader>tc', '<cmd>NoNeckPain<CR>', '[t]oggle [c]entering')
call s:Map('', '<leader>tu', '<cmd>UndotreeToggle<CR>', '[t]oggle [u]ndo tree')

" save the pinky
call s:Map('', '<leader>;', ':', 'Normal mode without shift')

" window splits
call s:Map('', '<leader>-', '<cmd>split<CR>', 'Split window horizontally')
" todo: consider a more ergonomic map
call s:Map('', '<leader><Bslash>', '<cmd>vsplit<CR>', 'Split window vertically')

" system clipboard interactions
call s:Map('n', '<leader>y', '"+y', '[Y]ank into clipboard')
call s:Map('v', '<leader>y', '"+y', '[Y]ank into clipboard')
call s:Map('n', '<leader>Y', '"+y$', '[Y]ank tail of line into clipboard')
call s:Map('n', '<leader>p', '"+p', '[P]aste from clipboard')
call s:Map('v', '<leader>p', '"+p', '[P]aste from clipboard')
call s:Map('n', '<leader>P', '"+P', '[P]aste from clipboard before cursor')

" quickfix list navigation
call s:Map('n', ']q', '<cmd>cnext<CR>', 'Next quickfix item')
call s:Map('n', '[q', '<cmd>cprev<CR>', 'Previous quickfix item')

call s:Map('', '<leader>w', '<cmd>write<CR>', '[W]rite current buffer')
call s:Map('', '<leader>q', '<cmd>confirm quitall<CR>', '[Q]uit with confirmation')
call s:Map('', '<C-w>go', '<cmd>tabonly<CR>')

" search, once fzf.vim is installed
if empty(s:missing)
  call s:Map('n', '<leader>F', '<cmd>Files<CR>', '[F]ind stuff')
  call s:Map('n', '<leader>ff', '<cmd>Files<CR>', '[F]ind [F]iles')
  call s:Map('n', '<leader>fg', '<cmd>Rg<CR>', '[F]ind with [G]rep')
  call s:Map('n', '<leader>fs', ':<C-U>Rg <C-r><C-a><CR>', '[F]ind [S]tring')
  call s:Map('n', '<leader>fk', '<cmd>Maps<CR>', '[F]ind [K]ey mapping')
  call s:Map('n', '<leader>fr', '<cmd>History<CR>', '[f]ind [r]ecent files')
  call s:Map('n', '<leader>fh', '<cmd>Helptags<CR>', '[F]ind [H]elp')
endif

" ---------------
" -- which-key --
" ---------------

" vim-which-key cannot read mapping descriptions, so the labels live here
let g:which_key_map = {
      \ 't': {'name': '+toggle', 'h': 'search highlighting', 's': 'spellchecking',
      \       'l': 'list chars', 'w': 'wrapping', 'c': 'centering', 'u': 'undo tree'},
      \ 'f': {'name': '+find', 'F': 'files', 'f': 'files', 'g': 'grep',
      \       's': 'word under cursor', 'k': 'key mappings', 'r': 'recent files',
      \       'h': 'help'},
      \ '-': 'split horizontally',
      \ '\': 'split vertically',
      \ ';': 'command-line',
      \ 'w': 'write buffer',
      \ 'q': 'quit with confirmation',
      \ 'y': 'yank to clipboard',
      \ 'Y': 'yank tail to clipboard',
      \ 'p': 'paste from clipboard',
      \ 'P': 'paste before cursor',
      \ }

if empty(s:missing)
  nnoremap <silent> <leader> :<C-U>WhichKey '<Space>'<CR>
  xnoremap <silent> <leader> :<C-U>WhichKeyVisual '<Space>'<CR>
  call which_key#register('<Space>', 'g:which_key_map')
endif

" ------------------
" -- autocommands --
" ------------------

" strip trailing whitespace on write
augroup init
  autocmd!
  autocmd BufWritePre * %s/\s\+$//e
augroup END

" ---------------
" -- filetypes --
" ---------------

" visually wrap lines, hide line break continuation markers, and give up the
" number column
function! s:Markdown() abort
  setlocal spell noexpandtab linebreak showbreak=NONE nonumber
  " swap gj/gk with j/k for finer navigation over wrapped lines
  nnoremap <buffer> <silent> j gj
  nnoremap <buffer> <silent> k gk
  nnoremap <buffer> <silent> gj j
  nnoremap <buffer> <silent> gk k
  vnoremap <buffer> <silent> j gj
  vnoremap <buffer> <silent> k gk
  vnoremap <buffer> <silent> gj j
  vnoremap <buffer> <silent> gk k
endfunction

augroup init
  " expandtab, 4-space indent
  autocmd FileType java,python,sh,zig setlocal expandtab softtabstop=4 shiftwidth=4
  " expandtab, 2-space indent
  autocmd FileType html,kotlin,swift,yaml setlocal expandtab softtabstop=2 shiftwidth=2
  autocmd FileType lua setlocal expandtab softtabstop=3 shiftwidth=3
  autocmd FileType gitcommit setlocal spell textwidth=72
  autocmd FileType go setlocal noexpandtab tabstop=8 shiftwidth=8
  autocmd FileType markdown call s:Markdown()
augroup END

" ----------------
" -- local config --
" ----------------

" per-machine overrides live outside the repository; the Lua fallback keeps
" existing local files working until they are migrated
let s:local = expand('~/.config/nvim/init.local.vim')
let s:local_lua = expand('~/.config/nvim/init.local.lua')
if filereadable(s:local)
  execute 'source ' . fnameescape(s:local)
elseif filereadable(s:local_lua)
  execute 'luafile ' . fnameescape(s:local_lua)
endif
