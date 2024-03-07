local eslint = require("efmls-configs.linters.eslint")
local stylua = require("efmls-configs.formatters.stylua")
local autopep8 = require("efmls-configs.formatters.autopep8")
local prettier = require("efmls-configs.formatters.prettier")

local languages = {
	typescript = { eslint, prettier },
	lua = { stylua },
	python = { autopep8 },
}

local efmls_config = {
	filetypes = vim.tbl_keys(languages),
	settings = {
		rootMarkers = { ".git/" },
		languages = languages,
	},
	init_options = {
		documentFormatting = true,
		documentRangeFormatting = true,
	},
}

require("lspconfig").efm.setup(vim.tbl_extend("force", efmls_config, {}))

vim.api.nvim_set_keymap("n", "<Leader>i", "<cmd>lua vim.lsp.buf.format()<cr>", { noremap = true })
