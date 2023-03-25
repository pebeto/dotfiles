require("sniprun").setup({
	display = { "NvimNotify" },
})

vim.api.nvim_set_keymap("v", "<leader>sr", "<Plug>SnipRun", { silent = true })
vim.api.nvim_set_keymap("n", "<leader>sr", "<Plug>SnipRun", { silent = true })
