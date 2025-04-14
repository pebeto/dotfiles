-- Line settings
vim.opt.cursorline = true -- Highlight the current line
vim.opt.number = true     -- Line numbers

-- Tab settings
vim.opt.tabstop = 4        -- Number of spaces a <Tab> counts for
vim.opt.shiftwidth = 4     -- Number of spaces to use for each step of (auto)indent
vim.opt.expandtab = true   -- Use spaces instead of tabs
vim.opt.smartindent = true -- Insert indents automatically

-- Highlight and color settings
vim.opt.hlsearch = true      -- Highlight search results
vim.opt.colorcolumn = "92"   -- Highlight column 80
vim.opt.termguicolors = true -- Enable 24-bit RGB color in the TUI
vim.cmd("colorscheme paper") -- Set colorscheme to paper

-- File settings
vim.opt.autoread = true -- Automatically read files when changed outside of Vim

vim.notify = require("notify") -- Using notify plugin for notifications
