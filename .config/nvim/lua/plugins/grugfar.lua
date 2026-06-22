require("grug-far").setup({})

-- <leader>s = "search & replace" (project-wide, with a live preview buffer).
vim.keymap.set("n", "<leader>sr", function()
    require("grug-far").open()
end, { desc = "Grug-far: search & replace" })

vim.keymap.set("n", "<leader>sw", function()
    require("grug-far").open({ prefills = { search = vim.fn.expand("<cword>") } })
end, { desc = "Grug-far: replace word under cursor" })

vim.keymap.set("x", "<leader>sr", function()
    require("grug-far").with_visual_selection()
end, { desc = "Grug-far: replace visual selection" })
