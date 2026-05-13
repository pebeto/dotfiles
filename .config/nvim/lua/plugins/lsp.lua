local servers = { "julials", "pyright", "ts_ls", "texlab", "lua_ls", "clangd" }

vim.lsp.config("julials", {
    filetypes = { "julia" },
})

for _, server in ipairs(servers) do
    vim.lsp.enable(server)
end

-- Inlay hints
vim.lsp.inlay_hint.enable(true)

-- Diagnostics
vim.diagnostic.config({
    virtual_text = { prefix = "●" },
    signs = true,
    underline = true,
    update_in_insert = false,
    severity_sort = true,
    float = { border = "rounded", source = true },
})

-- LSP keymaps (only active when an LSP is attached)
vim.api.nvim_create_autocmd("LspAttach", {
    callback = function(ev)
        local buf = ev.buf
        local map = function(mode, lhs, rhs, desc)
            vim.keymap.set(mode, lhs, rhs, { buffer = buf, desc = desc })
        end

        map("n", "<leader>lf", function()
            require("telescope.builtin").lsp_references()
        end, "LSP: Find references")
        map({ "n", "v" }, "<leader>la", vim.lsp.buf.code_action, "LSP: Code action")
        map("n", "<leader>lr", vim.lsp.buf.rename, "LSP: Rename")
        map("n", "<leader>lgd", vim.lsp.buf.definition, "LSP: Go to definition")
        map("n", "<leader>lpd", function()
            vim.lsp.buf.hover({ border = "rounded" })
        end, "LSP: Peek definition (hover)")
        map("n", "K", function()
            vim.lsp.buf.hover({ border = "rounded" })
        end, "LSP: Hover documentation")
        map("n", "<leader>lcd", vim.diagnostic.open_float, "LSP: Show cursor diagnostics")
        map("n", "<leader>lbd", function()
            vim.diagnostic.open_float(nil, { scope = "buffer" })
        end, "LSP: Show buffer diagnostics")
        map("n", "<leader>lic", vim.lsp.buf.incoming_calls, "LSP: Incoming calls")
        map("n", "<leader>loc", vim.lsp.buf.outgoing_calls, "LSP: Outgoing calls")
        map("n", "<leader>lh", function()
            vim.lsp.inlay_hint.enable(not vim.lsp.inlay_hint.is_enabled({ bufnr = buf }), { bufnr = buf })
        end, "LSP: Toggle inlay hints")
    end,
})

-- Diagnostic navigation (nvim 0.11+ API)
vim.keymap.set("n", "[e", function()
    vim.diagnostic.jump({ count = -1 })
end, { desc = "LSP: Previous diagnostic" })

vim.keymap.set("n", "]e", function()
    vim.diagnostic.jump({ count = 1 })
end, { desc = "LSP: Next diagnostic" })

vim.keymap.set("n", "[E", function()
    vim.diagnostic.jump({ count = -1, severity = vim.diagnostic.severity.ERROR })
end, { desc = "LSP: Previous error" })

vim.keymap.set("n", "]E", function()
    vim.diagnostic.jump({ count = 1, severity = vim.diagnostic.severity.ERROR })
end, { desc = "LSP: Next error" })
