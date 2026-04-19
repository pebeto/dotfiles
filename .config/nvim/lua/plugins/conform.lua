require("conform").setup({
	formatters_by_ft = {
		["*"] = { "trim_whitespace", "trim_newlines" },
		lua = { "stylua" },
		python = { "black" },
		typescript = { "prettier" },
		javascript = { "prettier" },
		typescriptreact = { "prettier" },
		javascriptreact = { "prettier" },
		markdown = { "prettier" },
		html = { "prettier" },
		css = { "prettier" },
		json = { "prettier" },
		yaml = { "prettier" },
		c = { "clang_format" },
		cpp = { "clang_format" },
		latex = { "latexindent" },
		tex = { "latexindent" },
	},
	format_after_save = false,
})

vim.keymap.set("n", "<leader>i", function()
	require("conform").format({ async = true, lsp_format = "fallback" })
end, { desc = "Format buffer" })
