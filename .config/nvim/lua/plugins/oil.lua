require("oil").setup({
	columns = {
		"icon",
		"permissions",
		"size",
		"mtime",
	},
	view_options = {
		show_hidden = true,
	},
})

vim.keymap.set("n", "<leader>c", "<cmd>Oil --float<CR>", { desc = "Toggle Oil file browser" })
