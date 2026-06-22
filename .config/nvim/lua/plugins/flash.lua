require("flash").setup()

local flash = require("flash")

-- s: jump anywhere on screen via labels.
vim.keymap.set({ "n", "x", "o" }, "s", function()
    flash.jump()
end, { desc = "Flash jump" })

-- S: select by Treesitter node (a function or block).
vim.keymap.set({ "n", "x", "o" }, "S", function()
    flash.treesitter()
end, { desc = "Flash Treesitter" })

-- <C-s> while in / or ? search: toggle jump labels on the matches.
vim.keymap.set("c", "<c-s>", function()
    flash.toggle()
end, { desc = "Toggle Flash search" })
