-------------
-- plugins --
-------------

-- bootstrap lazy.nvim
local lazypath = vim.fn.stdpath('data') .. '/lazy/lazy.nvim'
if not vim.uv.fs_stat(lazypath) then
   vim.fn.system({
      'git',
      'clone',
      '--filter=blob:none',
      'https://github.com/folke/lazy.nvim.git',
      '--branch=stable',
      lazypath,
   })
   -- pin the manager to the lockfile revision so machines agree on it
   local lockfile = vim.fn.stdpath('config') .. '/lazy-lock.json'
   local ok, lock = pcall(function()
      return vim.json.decode(table.concat(vim.fn.readfile(lockfile), '\n'))
   end)
   local pin = ok and type(lock) == 'table' and lock['lazy.nvim']
   if pin and pin.commit then
      vim.fn.system({ 'git', '-C', lazypath, 'checkout', '--quiet', pin.commit })
      if vim.v.shell_error ~= 0 then
         vim.notify('lazy.nvim ' .. pin.commit .. ' from the lockfile is unavailable', vim.log.levels.WARN)
      end
   end
end
-- add lazy.nvim to runtimepath first
vim.opt.rtp:prepend(lazypath)

-- map leader before any plugins define their mappings
vim.g.mapleader = ' '


local function is_journal_file(path)
   return path:find('journal')
end


require('lazy').setup({
   -- colorscheme
   { 'projekt0n/github-nvim-theme' },
   -- match system light/dark mode
   {
      'andreterroir/daybreak.nvim',
      opts = {
         light = 'github_light',
         dark = 'github_dark_dimmed',
      }
   },
   -- center the focused buffer
   {
      'shortcuts/no-neck-pain.nvim',
      opts = {},
   },
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
   {
      'windwp/nvim-autopairs',
      event = 'InsertEnter',
      config = function()
         local Rule = require('nvim-autopairs.rule')
         local npairs = require('nvim-autopairs')
         npairs.setup()
         npairs.add_rules({
            Rule('`', '`'),
         })
      end,
   },
   -- keymap discovery
   { 'folke/which-key.nvim' },
   -- persistent branching undo history
   'mbbill/undotree',
   -- preserve last session per directory
   {
      'folke/persistence.nvim',
      -- only start session saving when an actual file was opened
      event = 'BufReadPre',
      config = function()
         require('persistence').setup({})
         vim.api.nvim_create_user_command('Load', function()
            require('persistence').load()
         end, { nargs = 0 })
         vim.api.nvim_create_user_command('Last', function()
            require('persistence').load({ last = true })
         end, { nargs = 0 })
      end
   },
   -- navigation
   'christoomey/vim-tmux-navigator',
   -- search
   {
      'ibhagwan/fzf-lua',
      dependencies = { 'nvim-tree/nvim-web-devicons' },
      opts = {}
   },
   -- startup screen
   {
      'nvimdev/dashboard-nvim',
      event = 'VimEnter',
      opts = function()
         local opts = {
            theme = 'doom',
            config = {
               week_header = {
                  enable = true
               },
               -- stylua: ignore
               center = {
                  { action = 'JournalToday', desc = ' Today\'s journal', icon = '󰢧 ', key = 't' },
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
            }
         }

         -- close Lazy and re-open when the dashboard is ready
         if vim.o.filetype == 'lazy' then
            vim.cmd.close()
            vim.api.nvim_create_autocmd('User', {
               pattern = 'DashboardLoaded',
               callback = function()
                  require('lazy').show()
               end,
            })
         end

         return opts
      end,
      dependencies = { { 'nvim-tree/nvim-web-devicons' } }
   },
   -- persistent fast access terminal
   {
      'akinsho/toggleterm.nvim',
      config = function()
         require('toggleterm').setup({
            open_mapping = [[<a-;>]],
         })
      end
   },
   -- Git interface
   'tpope/vim-fugitive',
   -- inline Git interface
   {
      'lewis6991/gitsigns.nvim',
      opts = {
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
            -- show_deleted / toggle_deleted are deprecated
            map('n', '<leader>td', gs.preview_hunk_inline)

            -- text object
            map({ 'o', 'x' }, 'ih', ':<C-U>Gitsigns select_hunk<CR>')
         end
      }
   },
   {
      'stevearc/oil.nvim',
      config = true,
      dependencies = { 'nvim-tree/nvim-web-devicons' },
   }
}, {
   dev = {
      path = '~/code',
      patterns = { 'andreterroir' },
      fallback = true,
   },
})

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
   vim.fn.mkdir(backup_dir)
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
vim.keymap.set('', '<leader>tc', vim.cmd.NoNeckPain, { desc = '[t]oggle [c]entering' })

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

local fzf = require('fzf-lua')
vim.keymap.set('n', '<leader>F', vim.cmd.FzfLua, { desc = '[F]ind stuff' })
vim.keymap.set('n', '<leader>f<space>', fzf.resume, { desc = 'Resume [F]ind' })
vim.keymap.set('n', '<leader>ff', fzf.files, { desc = '[F]ind [F]iles' })
vim.keymap.set('n', '<leader>fg', fzf.live_grep, { desc = '[F]ind with [G]rep' })
vim.keymap.set('n', '<leader>fs', fzf.grep_cWORD, { desc = '[F]ind [S]tring' })
vim.keymap.set('n', '<leader>fk', fzf.keymaps, { desc = '[F]ind [K]ey mapping' })
vim.keymap.set('n', '<leader>fr', fzf.oldfiles, { desc = '[f]ind [r]ecent files' })
vim.keymap.set('n', '<leader>fh', fzf.helptags, { desc = '[F]ind [H]elp' })

local function journal_next(step)
   local buf_path = vim.api.nvim_buf_get_name(0)
   if not buf_path or buf_path == '' then
      vim.notify('buffer has no path', vim.log.levels.INFO)
      return
   end
   if not is_journal_file(buf_path) then
      vim.notify('not a journal buffer', vim.log.levels.INFO)
      return
   end
   local buf_file = vim.fn.fnamemodify(buf_path, ':t:r')
   local date_pattern = '(%d%d%d%d)%-(%d%d)%-(%d%d)'
   local year, month, day = buf_file:match(date_pattern)
   if not year or not month or not day then
      vim.notify('unexpected journal file format: ' .. buf_path, vim.log.levels.INFO)
      return
   end
   local curr_date = os.time({ year = year, month = month, day = day })
   for i = 1, 30 do -- only look for files within a month
      local next_date = os.date('%Y-%m-%d', curr_date + i * step * 24 * 3600)
      local next_file = buf_path:gsub(date_pattern, next_date)
      if vim.uv.fs_stat(next_file) then
         vim.cmd('edit ' .. next_file)
         return
      end
   end
   vim.notify('no more close journal files', vim.log.levels.INFO)
end
vim.keymap.set('n', '<leader>j;', function() journal_next(1) end, { desc = 'Open next journal file' })
vim.keymap.set('n', '<leader>j,', function() journal_next(-1) end, { desc = 'Open previous journal file' })

local function journal_for_offset(offset_days)
   local notes_dir = vim.fn.expand('~/notes')
   local date = os.date('%Y-%m-%d', os.time() + offset_days * 86400)
   local file = vim.fs.joinpath(notes_dir, 'journal', date .. '.md')
   vim.cmd('cd ' .. notes_dir)
   vim.cmd('edit ' .. file)
end
vim.api.nvim_create_user_command('JournalToday', function() journal_for_offset(0) end, { desc = "Open today's journal" })
vim.api.nvim_create_user_command('JournalTomorrow', function() journal_for_offset(1) end, { desc = "Open tomorrow's journal" })
vim.api.nvim_create_user_command('JournalYesterday', function() journal_for_offset(-1) end, { desc = "Open yesterday's journal" })

vim.keymap.set('', '<leader>U', vim.cmd.UndotreeToggle, { desc = 'Toggle [U] undo tree' })
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
      -- Workaround for the lack of a DAP strategy in neotest-go: https://github.com/nvim-neotest/neotest-go/issues/12
      vim.api.nvim_buf_set_keymap(0, '', '<leader>tD', '<cmd>lua require("dap-go").debug_test()<cr>', {})
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
