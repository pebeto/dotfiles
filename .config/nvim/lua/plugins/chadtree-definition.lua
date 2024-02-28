require('neo-tree').setup({
    filesystem = {
        filtered_items = {
            visible = true,
            hide_dotfiles = false,
            hide_gitignored = true
        }
    }
})

vim.api.nvim_set_keymap("n", "<Leader>c", "<cmd>Neotree<cr>", { noremap = true })
