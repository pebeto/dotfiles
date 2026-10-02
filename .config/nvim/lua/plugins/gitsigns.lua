require("gitsigns").setup({
    signcolumn = true,
    current_line_blame = true,
    current_line_blame_opts = {
        virt_text = true,
        virt_text_pos = "eol",
        delay = 1000,
        virt_text_priority = 100,
    },
    current_line_blame_formatter = "<author>, <author_time:%R> - <summary>",
    watch_gitdir = {
        follow_files = true,
    },
    auto_attach = true,
    max_file_length = 40000,
    preview_config = {
        border = "single",
        style = "minimal",
        relative = "cursor",
        row = 0,
        col = 1,
    },
    on_attach = function(bufnr)
        local gs = package.loaded.gitsigns
        local map = function(mode, lhs, rhs, desc)
            vim.keymap.set(mode, lhs, rhs, { buffer = bufnr, desc = desc })
        end

        -- Navigation. In a diff window ]c and [c keep their built-in meaning.
        map("n", "]c", function()
            if vim.wo.diff then
                vim.cmd.normal({ "]c", bang = true })
            else
                gs.nav_hunk("next")
            end
        end, "Git: Next hunk")
        map("n", "[c", function()
            if vim.wo.diff then
                vim.cmd.normal({ "[c", bang = true })
            else
                gs.nav_hunk("prev")
            end
        end, "Git: Prev hunk")

        -- Actions. stage_hunk toggles: on an already-staged hunk it unstages.
        map("n", "<leader>gs", gs.stage_hunk, "Git: Stage/unstage hunk")
        map("n", "<leader>gr", gs.reset_hunk, "Git: Reset hunk")
        -- In visual mode, act on the selected lines rather than the whole hunk.
        map("v", "<leader>gs", function()
            gs.stage_hunk({ vim.fn.line("."), vim.fn.line("v") })
        end, "Git: Stage/unstage lines")
        map("v", "<leader>gr", function()
            gs.reset_hunk({ vim.fn.line("."), vim.fn.line("v") })
        end, "Git: Reset lines")
        map("n", "<leader>gS", gs.stage_buffer, "Git: Stage buffer")
        map("n", "<leader>gR", gs.reset_buffer, "Git: Reset buffer")
        map("n", "<leader>gp", gs.preview_hunk, "Git: Preview hunk")
        map("n", "<leader>gb", function()
            gs.blame_line({ full = true })
        end, "Git: Blame line")
        map("n", "<leader>gd", gs.diffthis, "Git: Diff this")
    end,
})
