local null_ls = require("null-ls")

null_ls.setup({
    sources = {
        null_ls.builtins.formatting.stylua,
        null_ls.builtins.formatting.autopep8,
        null_ls.builtins.formatting.eslint,
        null_ls.builtins.formatting.prettier,
    }
})
vim.api.nvim_set_keymap("n", "<Leader>i", "<cmd>lua vim.lsp.buf.format()<cr>", { noremap = true })
