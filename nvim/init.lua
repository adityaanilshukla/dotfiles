-- options
vim.wo.relativenumber = true
-- Make plain y/p use the system clipboard

vim.opt.clipboard = "unnamedplus"

-- Reliable WSL clipboard via win32yank (fixes ^M / CRLF issues)
vim.g.clipboard = {
  name = "win32yank-wsl",
  copy = {
    ["+"] = "win32yank.exe -i --crlf",
    ["*"] = "win32yank.exe -i --crlf",
  },
  paste = {
    ["+"] = "win32yank.exe -o --lf",
    ["*"] = "win32yank.exe -o --lf",
  },
  cache_enabled = 0,
}

vim.opt.fillchars:append { eob = " " }
vim.wo.wrap = false
vim.o.sessionoptions ="blank,buffers,curdir,folds,help,tabpages,winsize,terminal,localoptions"

-- install pugins
vim.cmd([[
call plug#begin('~/.config/nvim/plugged')

Plug 'nvim-lua/plenary.nvim'
Plug 'nvim-telescope/telescope.nvim',

Plug 'nvim-neo-tree/neo-tree.nvim'
Plug 'MunifTanjim/nui.nvim'
Plug 'nvim-tree/nvim-web-devicons'
Plug 'nvim-lualine/lualine.nvim'

Plug 'numToStr/Comment.nvim'

Plug 'akinsho/toggleterm.nvim', {'tag' : '*'}

Plug 'nvim-treesitter/nvim-treesitter'

Plug 'shortcuts/no-neck-pain.nvim', { 'tag': '*' }

Plug 'EdenEast/nightfox.nvim'

Plug 'MeanderingProgrammer/render-markdown.nvim'

Plug 'romgrk/barbar.nvim'

Plug 'lukas-reineke/indent-blankline.nvim'

Plug 'rmagatti/auto-session'

call plug#end()
]])

-- Set leader key
vim.g.mapleader = " "  -- space as leader

require("auto-session").setup({
  auto_restore_enabled = false,
})

local map = vim.api.nvim_set_keymap
local opts = { noremap = true, silent = true }

map('n', '<leader>fs', ':AutoSession search<CR>', opts)
map('n', '<leader>ss', ':AutoSession save<CR>', opts)

-- Save current buffer: <leader>w
map('n', '<leader>w', ':w<CR>', opts)

-- Quit current buffer: <leader>q
map('n', '<leader>q', ':q<CR>', opts)

-- Quit all buffers / exit Neovim: <leader>x
map('n', '<leader>x', ':qa<CR>', opts)

-- change buffers
vim.keymap.set("n", "]b", ":bnext<CR>", { desc = "Next buffer" })
vim.keymap.set("n", "[b", ":bprevious<CR>", { desc = "Previous buffer" })

-- Key mappings
local map = vim.api.nvim_set_keymap
local opts = { noremap = true, silent = true }

-- Toggle Neo-tree with <leader>e
map('n', '<leader>e', ':Neotree toggle<CR>', opts)
-- Toggle focus back and forth from neotree
vim.keymap.set('n', '<leader>o', function()
  if vim.bo.filetype == 'neo-tree' then
    vim.cmd('wincmd p')
  else
    vim.cmd('Neotree focus')
  end
end, opts)

-- Open Telescope find_files with <leader>ff
map('n', '<leader>ff', ':Telescope find_files<CR>', opts)
map('n', '<leader>fh', ':Telescope find_files hidden=true<CR>', opts)

-- Toggle comment on a line with <leader>/
-- This eequires Comment.nvim to be setup
require('Comment').setup()
map('n', '<leader>/', '<cmd>lua require("Comment.api").toggle.linewise.current()<CR>', opts)
map('v', '<leader>/', '<esc><cmd>lua require("Comment.api").toggle.linewise(vim.fn.visualmode())<CR>', opts)

map("n", "<leader>cb", "<cmd>NoNeckPain<CR>", { noremap = true, silent = true, desc = "Center buffer" })

-- splits
--vertical split on leader |
vim.keymap.set("n", "|", ":vs<CR>", { noremap = true, desc = "Vertical Split" })
-- Horizontal split on <leader>\
vim.keymap.set("n", "<leader>\\", "<cmd>split<CR><C-w>w", { noremap = true, desc = "Horizontal Split" })

-- navigation
vim.keymap.set("n", "<C-h>", "<C-w>h", { silent = true })
vim.keymap.set("n", "<C-l>", "<C-w>l", { silent = true })
vim.keymap.set("n", "<C-j>", "<C-w>j", { silent = true })
vim.keymap.set("n", "<C-k>", "<C-w>k", { silent = true })

-- resize
vim.keymap.set("n", "<C-LEFT>", "<C-w><", { silent = true })
vim.keymap.set("n", "<C-Right>", "<C-w>>", { silent = true })
vim.keymap.set("n", "<C-Up>", "<C-w>+", { silent = true })
vim.keymap.set("n", "<C-Down>", "<C-w>-", { silent = true })

-- Close current buffer without closing the window
vim.api.nvim_set_keymap("n", "<Leader>c", ":bp|bd#<CR>", { noremap = true, silent = true })

-- toggleterm custom functions 
require("toggleterm").setup({
})
local Terminal = require("toggleterm.terminal").Terminal
local lazygit = Terminal:new({ cmd = "lazygit", hidden = true, direction="tab" })

local tab_term = Terminal:new({
  direction = "tab",
  hidden = true,
})

vim.keymap.set({ "n", "t" }, "<F7>", function()
  tab_term:toggle()
end, { desc = "Toggle terminal tab" })


function _lazygit_toggle()
  lazygit:toggle()
end

vim.api.nvim_set_keymap("n", "<leader>gg", "<cmd>lua _lazygit_toggle()<CR>", {noremap = true, silent = true})

require'nvim-treesitter'.setup {
  -- Directory to install parsers and queries to (prepended to `runtimepath` to have priority)
  install_dir = vim.fn.stdpath('data') .. '/site'
}
vim.api.nvim_create_autocmd('FileType', {
  pattern = { '<filetype>' },
  callback = function() vim.treesitter.start() end,
})

require('render-markdown').setup({
    completions = { lsp = { enabled = true } },
})


require('nightfox').setup()
vim.cmd("colorscheme carbonfox")
require('lualine').setup()
require('barbar').setup()
require("ibl").setup()
