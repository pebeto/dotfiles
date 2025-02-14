require("toggleterm").setup({
	size = function(term)
		if term.direction == "horizontal" then
			return 15
		elseif term.direction == "vertical" then
			return vim.o.columns * 0.4
		end
	end,
})

function _G.set_terminal_keymaps()
	local opts = { buffer = 0 }
	vim.keymap.set("t", "<esc>", [[<C-\><C-n>]], opts)
	vim.keymap.set("t", "<C-h>", [[<C-\><C-n><C-W>h]], opts)
	vim.keymap.set("t", "<C-j>", [[<C-\><C-n><C-W>j]], opts)
	vim.keymap.set("t", "<C-k>", [[<C-\><C-n><C-W>k]], opts)
	vim.keymap.set("t", "<C-l>", [[<C-\><C-n><C-W>l]], opts)
end

vim.cmd("autocmd! TermOpen term://* lua set_terminal_keymaps()")

vim.keymap.set("n", "<Leader>t", "<cmd>exe v:count1 . 'ToggleTerm'<cr>", { noremap = true })
