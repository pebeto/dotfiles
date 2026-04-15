-- Line settings
vim.opt.cursorline = true -- Highlight the current line
vim.opt.number = true -- Line numbers
vim.opt.conceallevel = 2 -- Show concealed text

-- Tab settings
vim.opt.tabstop = 4 -- Spaces per <Tab>
vim.opt.shiftwidth = 4 -- Spaces per indent step
vim.opt.expandtab = true -- Spaces instead of tabs
vim.opt.smartindent = true -- Auto-indent on new lines

-- Highlight and color settings
vim.opt.hlsearch = true -- Highlight search results
vim.opt.colorcolumn = "92" -- Highlight column 92
vim.opt.termguicolors = true -- 24-bit color in TUI

-- File settings
vim.opt.autoread = true -- Auto-reload files changed externally

vim.cmd("colorscheme dookie")

-- Notifications (must be early so conform/lint can use vim.notify)
require("notify").setup({
	fps = 60,
	stages = "slide",
	render = "wrapped-compact",
})
vim.notify = require("notify")
