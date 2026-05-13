require("toggleterm").setup({
    size = function(term)
        if term.direction == "horizontal" then
            return 15
        elseif term.direction == "vertical" then
            return vim.o.columns * 0.4
        end
    end,
})

vim.api.nvim_create_autocmd("TermOpen", {
    pattern = "term://*",
    callback = function()
        vim.keymap.set("t", "<esc>", [[<C-\><C-n>]], { buffer = 0 })
        vim.keymap.set("t", "<C-h>", [[<C-\><C-n><C-W>h]], { buffer = 0 })
        vim.keymap.set("t", "<C-j>", [[<C-\><C-n><C-W>j]], { buffer = 0 })
        vim.keymap.set("t", "<C-k>", [[<C-\><C-n><C-W>k]], { buffer = 0 })
        vim.keymap.set("t", "<C-l>", [[<C-\><C-n><C-W>l]], { buffer = 0 })
    end,
})

vim.keymap.set("n", "<leader>t", "<cmd>exe v:count1 . 'ToggleTerm'<cr>", { desc = "Toggle terminal" })
