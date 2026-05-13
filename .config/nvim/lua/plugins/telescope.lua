local builtin = require("telescope.builtin")

local function pick(key, func, desc)
    vim.keymap.set("n", key, func, { desc = desc })
end

pick("<leader>ff", builtin.find_files, "Telescope: Find files")
pick("<leader>fg", builtin.live_grep, "Telescope: Live grep")
pick("<leader>fb", builtin.buffers, "Telescope: Buffers")
pick("<leader>fo", builtin.oldfiles, "Telescope: Old files")
pick("<leader>fh", builtin.help_tags, "Telescope: Help tags")
pick("<leader>fr", builtin.lsp_references, "Telescope: LSP references")
pick("<leader>fd", builtin.lsp_definitions, "Telescope: LSP definitions")
pick("<leader>fa", builtin.commands, "Telescope: Commands")
pick("<leader>fn", function()
    require("telescope").extensions.notify.notify()
end, "Telescope: Notifications")
