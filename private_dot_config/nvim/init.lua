-------------
-- plugins --
-------------

-- bootstrap vim-plug, pinned so every machine gets the same manager
local plug_commit = '4c4e56b5f7384369927a075804b6a17de7644edd'
local plugpath = vim.fn.stdpath('data') .. '/site/autoload/plug.vim'
if vim.fn.filereadable(plugpath) == 0 then
   vim.fn.system({
      'curl',
      '-sfLo',
      plugpath,
      '--create-dirs',
      'https://raw.githubusercontent.com/junegunn/vim-plug/' .. plug_commit .. '/plug.vim',
   })
   -- neovim caches runtimepath lookups at startup, so a file written during
   -- this run is not found by autoload until it is sourced
   vim.cmd('source ' .. vim.fn.fnameescape(plugpath))
end

-- map leader before any plugins define their mappings
vim.g.mapleader = ' '

vim.cmd(('call plug#begin(%s)'):format(vim.fn.string(vim.fn.expand('~/.vim/plugged'))))

for _, repo in ipairs({
   -- colorscheme
   'projekt0n/github-nvim-theme',
   -- match system light/dark mode
   'andreterroir/daybreak.nvim',
   -- center the focused buffer
   'shortcuts/no-neck-pain.nvim',
   -- restrict allowed modeline options
   'ypcrts/securemodelines',
   -- readline style editing keybindings
   'tpope/vim-rsi',
   -- repeat plugin commands with dot
   'tpope/vim-repeat',
   -- highlight and navigate matching text
   'andymass/vim-matchup',
   -- add, change and delete surrounding characters
   'tpope/vim-surround',
   -- insert and step over matching characters
   'windwp/nvim-autopairs',
   -- keymap discovery
   'folke/which-key.nvim',
   -- persistent branching undo history
   'mbbill/undotree',
   -- preserve last session per directory
   'folke/persistence.nvim',
   -- navigation
   'christoomey/vim-tmux-navigator',
   -- search
   'ibhagwan/fzf-lua',
   'nvim-tree/nvim-web-devicons',
   -- startup screen
   'nvimdev/dashboard-nvim',
   -- persistent fast access terminal
   'akinsho/toggleterm.nvim',
   -- Git interface
   'tpope/vim-fugitive',
   -- inline Git interface
   'lewis6991/gitsigns.nvim',
   -- file manager
   'stevearc/oil.nvim',
}) do
   vim.cmd(("Plug '%s'"):format(repo))
end

vim.cmd('call plug#end()')

-- lazy ran each plugin's configuration in a pcall, so a plugin that fails to
-- load only loses its own settings
local function configure(name, fn)
   local ok, err = pcall(fn)
   if not ok then
      vim.notify(('nvim: %s failed to configure: %s'):format(name, err), vim.log.levels.ERROR)
   end
end

-- vim-plug leaves uninstalled plugins off the runtimepath, so configuring them
-- before :PlugInstall has run would abort this file on a new machine
local missing = vim.tbl_filter(function(plug)
   return vim.fn.isdirectory(plug.dir) == 0
end, vim.tbl_values(vim.g.plugs))

if #missing > 0 then
   vim.notify(
      ('vim-plug: %d plugin(s) missing, run :PlugInstall and restart'):format(#missing),
      vim.log.levels.WARN
   )
else
   configure('daybreak', function()
      require('daybreak').setup({
         light = 'github_light',
         dark = 'github_dark_dimmed',
      })
   end)

   configure('no-neck-pain', function()
      require('no-neck-pain').setup({ width = 80 })
   end)

   configure('nvim-autopairs', function()
      local Rule = require('nvim-autopairs.rule')
      local npairs = require('nvim-autopairs')
      npairs.setup()
      npairs.add_rules({
         Rule('`', '`'),
      })
   end)

   configure('persistence', function()
      require('persistence').setup({})
      vim.api.nvim_create_user_command('Load', function()
         require('persistence').load()
      end, { nargs = 0 })
      vim.api.nvim_create_user_command('Last', function()
         require('persistence').load({ last = true })
      end, { nargs = 0 })
   end)

   configure('fzf-lua', function()
      local fzf = require('fzf-lua')
      fzf.setup({})
      vim.keymap.set('n', '<leader>F', vim.cmd.FzfLua, { desc = '[F]ind stuff' })
      vim.keymap.set('n', '<leader>f<space>', fzf.resume, { desc = 'Resume [F]ind' })
      vim.keymap.set('n', '<leader>ff', fzf.files, { desc = '[F]ind [F]iles' })
      vim.keymap.set('n', '<leader>fg', fzf.live_grep, { desc = '[F]ind with [G]rep' })
      vim.keymap.set('n', '<leader>fs', fzf.grep_cWORD, { desc = '[F]ind [S]tring' })
      vim.keymap.set('n', '<leader>fk', fzf.keymaps, { desc = '[F]ind [K]ey mapping' })
      vim.keymap.set('n', '<leader>fr', fzf.oldfiles, { desc = '[f]ind [r]ecent files' })
      vim.keymap.set('n', '<leader>fh', fzf.helptags, { desc = '[F]ind [H]elp' })
   end)

   configure('dashboard', function()
      require('dashboard').setup({
         theme = 'doom',
         config = {
            week_header = {
               enable = true
            },
            -- stylua: ignore
            center = {
               { action = 'FzfLua files', desc = ' Find file', icon = ' ', key = 'f' },
               { action = 'ene | startinsert', desc = ' New file', icon = ' ', key = 'n' },
               { action = 'FzfLua oldfiles', desc = ' Recent files', icon = ' ', key = 'r' },
               { action = 'FzfLua live_grep', desc = ' Find text', icon = ' ', key = 'g' },
               { action = 'edit ~/.config/nvim/init.lua', desc = ' Config', icon = ' ', key = 'c' },
               { action = 'lua require("persistence").load()', desc = ' Load Session', icon = ' ', key = 's' },
               {
                  action = 'lua require("persistence").load({last = true})',
                  desc = ' Last Session',
                  icon = '󰼛 ',
                  key = 'l'
               },
               { action = 'qa', desc = ' Quit', icon = ' ', key = 'q' },
            },
            -- dashboard-nvim counts plugins only for lazy, packer and vim.pack
            footer = function()
               return { '', ('neovim loaded %d plugins'):format(#vim.tbl_keys(vim.g.plugs)) }
            end,
         }
      })
   end)

   configure('toggleterm', function()
      require('toggleterm').setup({
         open_mapping = [[<a-;>]],
      })
   end)

   configure('gitsigns', function()
      require('gitsigns').setup({
         on_attach = function(bufnr)
            local gs = package.loaded.gitsigns

            local function map(mode, l, r, opts)
               opts = opts or {}
               opts.buffer = bufnr
               vim.keymap.set(mode, l, r, opts)
            end

            -- navigation
            map('n', ']c', function()
               if vim.wo.diff then
                  vim.cmd.normal({ ']c', bang = true })
               else
                  gs.nav_hunk('next')
               end
            end)

            map('n', '[c', function()
               if vim.wo.diff then
                  vim.cmd.normal({ '[c', bang = true })
               else
                  gs.nav_hunk('prev')
               end
            end)

            -- actions
            map({ 'n', 'v' }, '<leader>hs', gs.stage_hunk)
            map({ 'n', 'v' }, '<leader>hr', gs.reset_hunk)
            map('n', '<leader>hS', gs.stage_buffer)
            -- stage_hunk on a staged hunk unstages it (undo_stage_hunk is deprecated)
            map('n', '<leader>hu', gs.stage_hunk)
            map('n', '<leader>hR', gs.reset_buffer)
            map('n', '<leader>hp', gs.preview_hunk)
            map('n', '<leader>hb', function() gs.blame_line { full = true } end)
            map('n', '<leader>tb', gs.toggle_current_line_blame, { desc = '[t]oggle [b]lame' })
            map('n', '<leader>hd', gs.diffthis)
            map('n', '<leader>hD', function() gs.diffthis('~') end)
            map('n', '<leader>hi', gs.preview_hunk_inline)

            -- text object
            map({ 'o', 'x' }, 'ih', ':<C-U>Gitsigns select_hunk<CR>')
         end
      })
   end)

   configure('oil', function()
      require('oil').setup()
   end)
end

-------------
-- options --
-------------
-- blinking block cursor for insert, replace, command and terminal modes
vim.opt.guicursor = {
   'i-r-c-ci-cr-t:block-blinkwait300-blinkoff150-blinkon150'
}

vim.cmd.syntax 'off'
vim.cmd.filetype 'plugin off'
-- enable true color support
vim.opt.termguicolors = true

-- render tabs as 4 spaces
vim.opt.tabstop = 4
-- insert 4 spaces for a tab
vim.opt.softtabstop = 4
-- insert 4 spaces for an indent
vim.opt.shiftwidth = 4
-- replace each 8 spaces by a tab
vim.opt.expandtab = false

-- use space as vertical split character
vim.opt.fillchars:append('vert: ')
-- show trailing characters, tabs and non-breakable spaces
vim.opt.list = true
vim.opt.listchars:append('tab:  ')
vim.opt.listchars:append('trail:·')
vim.opt.listchars:append('nbsp:⍽')
-- show when line continues outside of screen
vim.opt.listchars:append('extends:»')
vim.opt.listchars:append('precedes:«')
-- indent wrapped lines
vim.opt.breakindent = true
-- show marker for wrapped lines
vim.opt.showbreak = '↳ '
-- recognize bullet point as well as numbered lists: optional whitespace
-- followed either by a digit with an optional ]/:/./)/} or -/*/+
-- with at least one space after
vim.opt.formatlistpat = '^\\s*\\(\\d\\+[\\]:.)}]*\\|[-\\*+]\\)\\s\\+'
-- before indented text; shift lists by width of the prefix pattern (above)
vim.opt.breakindentopt = 'sbr,list:-1'
-- in the number column
vim.opt.cpoptions:append('n')
-- conceal syntax (e.g. Markdown), but not completely (highlight code block marks)
vim.opt.conceallevel = 1
-- display line numbers
vim.opt.number = true
-- highlight the line number for the current line
vim.opt.cursorline = true
vim.opt.cursorlineopt = 'number'
-- always display the line info column to avoid jumping
vim.opt.signcolumn = 'yes'
-- open folds by default
vim.opt.foldlevelstart = 99

-- do not highlight search results by default
vim.opt.hlsearch = false
-- autocomplete to the longest commons string and than cycle through the
-- alternatives
vim.opt.wildmode = 'longest:full,full'

-- keep backup if file is overwritten
vim.opt.backup = true
-- make a copy to create a backup, overwrite the original file in place
-- this preserves the file creation timestamp (birthtime)
vim.opt.backupcopy = 'yes'
-- create backupdir if doesn't exist
local backup_dir = vim.env.HOME .. '/.cache/nvim/backup'
if vim.fn.isdirectory(backup_dir) ~= 1 then
   vim.fn.mkdir(backup_dir, 'p')
end
-- save all backups in one place rather than in .
vim.opt.backupdir = backup_dir
-- persist undo history
vim.opt.undofile = true

------------
-- keymap --
------------

-- Empty string is an equivalent of :map, which applies to
-- normal, visual, select and operator-pending mode.

-- toggles
vim.keymap.set('', '<leader>th', '<cmd>set hlsearch!<CR>', { desc = '[t]oggle search [h]ighlighting' })
vim.keymap.set('', '<leader>ts', '<cmd>set spell!<CR>', { desc = '[t]oggle [s]pellchecking' })
vim.keymap.set('', '<leader>tl', '<cmd>set list!<CR>', { desc = '[t]oggle [l]ist chars' })
vim.keymap.set('', '<leader>tw', function()
   local wrap = not vim.wo.wrap
   vim.o.wrap = wrap
   vim.o.linebreak = wrap
end, { desc = '[t]oggle [w]rapping' })
vim.keymap.set('', '<leader>tc', vim.cmd.NoNeckPain, { desc = '[t]oggle [c]entering' })
vim.keymap.set('', '<leader>tu', vim.cmd.UndotreeToggle, { desc = '[t]oggle [u]ndo tree' })

-- save the pinky
vim.keymap.set('', '<leader>;', ':', { desc = 'Normal mode without shift' })

-- window splits
vim.keymap.set('', '<leader>-', vim.cmd.split, { desc = 'Split window horizontally' })
-- todo: consider a more ergonomic map
vim.keymap.set('', '<leader>\\', vim.cmd.vsplit, { desc = 'Split window vertically' })

-- system clipboard interactions
vim.keymap.set({ 'n', 'v' }, '<leader>y', [["+y]], { desc = '[Y]ank into clipboard' })
vim.keymap.set('n', '<leader>Y', [["+y$]], { desc = '[Y]ank tail of line into clipboard' })
vim.keymap.set({ 'n', 'v' }, '<leader>p', [["+p]], { desc = '[P]aste from clipboard' })
vim.keymap.set('n', '<leader>P', [["+P]], { desc = '[P]aste from clipboard before cursor' })

-- quickfix list navigation
vim.keymap.set('n', ']q', ':cnext<CR>', { desc = 'Next quickfix item' })
vim.keymap.set('n', '[q', ':cprev<CR>', { desc = 'Previous quickfix item' })

vim.keymap.set('', '<leader>w', '<cmd>:write<cr>', { desc = '[W]rite current buffer' })
vim.keymap.set('', '<leader>q', '<cmd>:confirm quitall<cr>', { desc = '[Q]uit with confirmation' })
vim.keymap.set('', '<C-w>go', '<cmd>:tabonly<cr>')

------------------
-- autocommands --
------------------

local augroup = vim.api.nvim_create_augroup('init', {})

-- strip trailing whitespace on write
vim.api.nvim_create_autocmd({ 'BufWritePre' }, {
   group = augroup,
   pattern = '*',
   command = [[%s/\s\+$//e]],
})

---------------
-- filetypes --
---------------

-- expandtab, 4-space indent
vim.api.nvim_create_autocmd({ 'FileType' }, {
   group = augroup,
   pattern = { 'java', 'python', 'sh', 'zig' },
   callback = function()
      vim.opt_local.expandtab = true
      vim.opt_local.softtabstop = 4
      vim.opt_local.shiftwidth = 4
   end,
})
-- expandtab, 2-space indent
vim.api.nvim_create_autocmd({ 'FileType' }, {
   group = augroup,
   pattern = { 'html', 'kotlin', 'swift', 'yaml' },
   callback = function()
      vim.opt_local.expandtab = true
      vim.opt_local.softtabstop = 2
      vim.opt_local.shiftwidth = 2
   end,
})
vim.api.nvim_create_autocmd({ 'FileType' }, {
   group = augroup,
   pattern = { 'lua' },
   callback = function()
      vim.opt_local.expandtab = true
      vim.opt_local.softtabstop = 3
      vim.opt_local.shiftwidth = 3
   end,
})
vim.api.nvim_create_autocmd({ 'FileType' }, {
   group = augroup,
   pattern = { 'gitcommit' },
   callback = function()
      vim.opt_local.spell = true
      vim.opt_local.textwidth = 72
   end,
})
vim.api.nvim_create_autocmd({ 'FileType' }, {
   group = augroup,
   pattern = { 'go' },
   callback = function()
      vim.opt_local.expandtab = false
      vim.opt_local.tabstop = 8
      vim.opt_local.shiftwidth = 8
   end,
})
vim.api.nvim_create_autocmd({ 'FileType' }, {
   group = augroup,
   pattern = { 'markdown' },
   callback = function()
      vim.opt_local.spell = true
      vim.opt_local.expandtab = false
      -- visually wrap lines
      vim.opt_local.linebreak = true
      -- hide line break continuation markers
      vim.opt_local.showbreak = 'NONE'
      vim.opt_local.number = false
      -- swap gj/gk with j/k for finer navigation over wrapped lines
      vim.keymap.set({ 'n', 'v' }, 'j', 'gj', { silent = true, buffer = true })
      vim.keymap.set({ 'n', 'v' }, 'k', 'gk', { silent = true, buffer = true })
      vim.keymap.set({ 'n', 'v' }, 'gj', 'j', { silent = true, buffer = true })
      vim.keymap.set({ 'n', 'v' }, 'gk', 'k', { silent = true, buffer = true })
   end,
})

------------------
-- local config --
------------------

local local_init = vim.env.HOME .. '/.config/nvim/init.local.lua'
if vim.fn.filereadable(local_init) ~= 0 then
   dofile(local_init)
end
