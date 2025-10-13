vim.lsp.config('julials', {})
vim.lsp.config('pyright', {})
vim.lsp.config('ts_ls', {})
vim.lsp.config('texlab', {})
vim.lsp.config('lua_ls', {})
vim.lsp.config('clangd', {
    cmd = {
        "clangd",
        "--offset-encoding=utf-16",
    },
})
vim.lsp.config('java_language_server', {})
vim.lsp.config('zls', {})

-- LSP finder - Find the symbol's definition
-- If there is no definition, it will instead be hidden
-- When you use an action in finder like "open vsplit",
-- you can use <C-t> to jump back
vim.keymap.set("n", "<leader>lf", "<cmd>Lspsaga finder<CR>")

-- Code action
vim.keymap.set({ "n", "v" }, "<leader>a", "<cmd>Lspsaga code_action<CR>")

-- Rename all occurrences of the hovered word for the entire file
vim.keymap.set("n", "<leader>rn", "<cmd>Lspsaga rename<CR>")

-- Rename all occurrences of the hovered word for the selected files
vim.keymap.set("n", "<leader>rn", "<cmd>Lspsaga rename ++project<CR>")

-- Peek definition
-- You can edit the file containing the definition in the floating window
-- It also supports open/vsplit/etc operations, do refer to "definition_action_keys"
-- It also supports tagstack
-- Use <C-t> to jump back
vim.keymap.set("n", "<leader>pd", "<cmd>Lspsaga peek_definition<CR>")

-- Go to definition
vim.keymap.set("n", "<leader>gd", "<cmd>Lspsaga goto_definition<CR>")

-- Show line diagnostics
-- You can pass argument ++unfocus to
-- unfocus the show_line_diagnostics floating window
vim.keymap.set("n", "<leader>sl", "<cmd>Lspsaga show_line_diagnostics<CR>")

-- Show cursor diagnostics
-- Like show_line_diagnostics, it supports passing the ++unfocus argument
vim.keymap.set("n", "<leader>sc", "<cmd>Lspsaga show_cursor_diagnostics<CR>")

-- Show buffer diagnostics
vim.keymap.set("n", "<leader>sb", "<cmd>Lspsaga show_buf_diagnostics<CR>")

-- Diagnostic jump
-- You can use <C-o> to jump back to your previous location
vim.keymap.set("n", "[e", "<cmd>Lspsaga diagnostic_jump_prev<CR>")
vim.keymap.set("n", "]e", "<cmd>Lspsaga diagnostic_jump_next<CR>")

-- Diagnostic jump with filters such as only jumping to an error
vim.keymap.set("n", "[E", function()
    require("lspsaga.diagnostic"):goto_prev({ severity = vim.diagnostic.severity.ERROR })
end)
vim.keymap.set("n", "]E", function()
    require("lspsaga.diagnostic"):goto_next({ severity = vim.diagnostic.severity.ERROR })
end)

-- Toggle outline
vim.keymap.set("n", "<leader>o", "<cmd>Lspsaga outline<CR>")

-- Hover Doc
-- If there is no hover doc,
-- there will be a notification stating that
-- there is no information available.
-- To disable it just use ":Lspsaga hover_doc ++quiet"
-- Pressing the key twice will enter the hover window
vim.keymap.set("n", "K", "<cmd>Lspsaga hover_doc<CR>")

-- If you want to keep the hover window in the top right hand corner,
-- you can pass the ++keep argument
-- Note that if you use hover with ++keep, pressing this kkey again will
-- close the hover window. If you want to jump to the hover window
-- you should use the wincmd command "<C-w>w"
vim.keymap.set("n", "<leader>K", "<cmd>Lspsaga hover_doc ++keep<CR>")

-- Call hierarchy
vim.keymap.set("n", "<Leader>ic", "<cmd>Lspsaga incoming_calls<CR>")
vim.keymap.set("n", "<Leader>oc", "<cmd>Lspsaga outgoing_calls<CR>")

-- Floating terminal
vim.keymap.set({ "n", "t" }, "<A-t>", "<cmd>Lspsaga term_toggle<CR>")
