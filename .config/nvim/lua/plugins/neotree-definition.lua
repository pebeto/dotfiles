require("neo-tree").setup({
	filesystem = {
		filtered_items = {
			visible = true,
			hide_dotfiles = false,
			hide_gitignored = true,
		},
		use_libuv_file_watcher = true,
	},
})

vim.api.nvim_set_keymap("n", "<Leader>c", "<cmd>Neotree toggle<cr>", { noremap = true })
