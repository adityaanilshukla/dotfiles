-- options
vim.wo.relativenumber = true
vim.wo.number = true
-- Make plain y/p use the system clipboard

vim.opt.clipboard = "unnamedplus"
vim.opt.spell = true
vim.opt.spelllang = { "en_us" }
vim.api.nvim_create_autocmd("ColorScheme", {
  pattern = "*",
  callback = function()
    vim.cmd("highlight SpellBad gui=underline cterm=underline")
  end,
})

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
vim.o.sessionoptions ="blank,buffers,curdir,folds,help,tabpages,winsize,localoptions"

-- vim.o.foldmethod = "expr"
-- vim.o.foldexpr = "nvim_treesitter#foldexpr()"
-- vim.o.foldlevel = 0

-- install pugins
vim.cmd([[
call plug#begin('~/.config/nvim/plugged')

Plug 'nvim-lua/plenary.nvim'
Plug 'nvim-telescope/telescope.nvim'

Plug 'nvim-neo-tree/neo-tree.nvim'
Plug 'MunifTanjim/nui.nvim'
Plug 'nvim-tree/nvim-web-devicons'
Plug 'nvim-lualine/lualine.nvim'

Plug 'numToStr/Comment.nvim'

Plug 'akinsho/toggleterm.nvim', {'tag' : '*'}

Plug 'nvim-treesitter/nvim-treesitter', {'do': ':TSUpdate'}

Plug 'shortcuts/no-neck-pain.nvim', { 'tag': '*' }

Plug 'EdenEast/nightfox.nvim'

Plug 'MeanderingProgrammer/render-markdown.nvim'

Plug 'romgrk/barbar.nvim'

Plug 'lukas-reineke/indent-blankline.nvim'

Plug 'rmagatti/auto-session'

call plug#end()
]])

require("neo-tree").setup({
  filesystem = {
    filtered_items = {
      hide_gitignored = false,
    },
  },

  window = {
    mappings = {
      ["Y"] = function(state)
        local node = state.tree:get_node()
        local filepath = node:get_id()
        local filename = node.name
        local modify = vim.fn.fnamemodify

        local results = {
          filepath,
          modify(filepath, ":."),
          modify(filepath, ":~"),
          filename,
          modify(filename, ":r"),
          modify(filename, ":e"),
        }

        local i = vim.fn.inputlist({
          "Choose to copy to clipboard:",
          "1. Absolute path: " .. results[1],
          "2. Path relative to CWD: " .. results[2],
          "3. Path relative to HOME: " .. results[3],
          "4. Filename: " .. results[4],
          "5. Filename without extension: " .. results[5],
          "6. Extension of the filename: " .. results[6],
        })

        if i > 0 then
          local result = results[i]
          if not result then
            return print("Invalid choice: " .. i)
          end
          vim.fn.setreg("+", result)
          vim.notify("Copied: " .. result)
        end
      end,
    },
  },
})

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


local builtin = require("telescope.builtin")

-- Open Telescope find_files with <leader>ff
map("n", "<leader>ff", "<cmd>Telescope find_files<CR>", opts)
-- map("n", "<leader>fh", "<cmd>Telescope find_files hidden=true<CR>", opts)
map("n", "<leader>fh", "<cmd>Telescope find_files hidden=true no_ignore=true<CR>", opts)
-- map("n", "<leader>fh",
--   "<cmd>lua require('telescope.builtin').find_files({ hidden = true, no_ignore = true, file_ignore_patterns = { '%.venv/' } })<CR>",
--   opts
-- )

map('n', '<leader>fw', "<cmd>lua require('telescope.builtin').live_grep()<CR>", { desc = "Telescope live grep" })
vim.keymap.set("n", "<leader>ft", function()builtin.colorscheme({ enable_preview = true })end, { desc = "Find themes" })

-- map("n", "<leader>ft", function()
--   builtin.colorscheme({ enable_preview = true })
-- end, {
--   desc = "Find themes",
-- })

-- Toggle comment on a line with <leader>/
-- This requires Comment.nvim to be setup
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

-- spell check
vim.keymap.set("n", "sc", "z=", { noremap = true })
-- toggleterm custom functions 
require("toggleterm").setup({
  size = 20,
  direction = "tab",        -- use tab, it's the cleanest on WSL+tmux (no split redraw bugs)
  shade_terminals = false,  -- shading uses extra escape sequences, can cause artifacts on WSL
  persist_mode = true,
  start_in_insert = true,
  auto_scroll = true,
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

require("nvim-treesitter.config").setup({
  ensure_installed = {
    "java",
    "python",
    "javascript",
    "cpp",
    "dockerfile",
    "bash",
    "lua",
    "markdown",
  },
  highlight = { enable = true },
  indent = { enable = true },
})

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
