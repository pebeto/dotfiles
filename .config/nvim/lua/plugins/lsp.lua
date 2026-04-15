local servers = { "julials", "pyright", "ts_ls", "texlab", "lua_ls" }

vim.lsp.config("julials", {
	filetypes = { "julia" },
})

for _, server in ipairs(servers) do
	vim.lsp.enable(server)
end

vim.lsp.enable("clangd")

-- LSP keymaps
vim.keymap.set("n", "<leader>lf", function()
	require("telescope.builtin").lsp_references()
end, { desc = "LSP: Find references" })

vim.keymap.set({ "n", "v" }, "<leader>la", vim.lsp.buf.code_action, { desc = "LSP: Code action" })

vim.keymap.set("n", "<leader>lr", vim.lsp.buf.rename, { desc = "LSP: Rename" })

vim.keymap.set("n", "<leader>lgd", vim.lsp.buf.definition, { desc = "LSP: Go to definition" })

vim.keymap.set("n", "<leader>lpd", vim.lsp.buf.definition, { desc = "LSP: Peek definition" })

vim.keymap.set("n", "K", function()
	vim.lsp.buf.hover({ border = "rounded" })
end, { desc = "LSP: Hover documentation" })

vim.keymap.set("n", "<leader>lcd", vim.diagnostic.open_float, { desc = "LSP: Show cursor diagnostics" })

vim.keymap.set("n", "<leader>lbd", function()
	vim.diagnostic.open_float(nil, { scope = "buffer" })
end, { desc = "LSP: Show buffer diagnostics" })

-- Diagnostic navigation
vim.keymap.set("n", "[e", vim.diagnostic.goto_prev, { desc = "LSP: Previous diagnostic" })
vim.keymap.set("n", "]e", vim.diagnostic.goto_next, { desc = "LSP: Next diagnostic" })

vim.keymap.set("n", "[E", function()
	vim.diagnostic.goto_prev({ severity = vim.diagnostic.severity.ERROR })
end, { desc = "LSP: Previous error" })

vim.keymap.set("n", "]E", function()
	vim.diagnostic.goto_next({ severity = vim.diagnostic.severity.ERROR })
end, { desc = "LSP: Next error" })

-- Call hierarchy
vim.keymap.set("n", "<leader>lic", vim.lsp.buf.incoming_calls, { desc = "LSP: Incoming calls" })
vim.keymap.set("n", "<leader>loc", vim.lsp.buf.outgoing_calls, { desc = "LSP: Outgoing calls" })
