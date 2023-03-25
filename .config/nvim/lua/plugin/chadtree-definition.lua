local chadtree_settings = {
	["options.show_hidden"] = false,
	["ignore.name_glob"] = { ".*" },
}

vim.api.nvim_set_var("chadtree_settings", chadtree_settings)

vim.api.nvim_set_keymap("n", "<Leader>c", "<cmd>CHADopen<cr>", { noremap = true })
