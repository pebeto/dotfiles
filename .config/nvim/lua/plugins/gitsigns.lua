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

		-- Navigation
		map("n", "]c", function()
			if vim.wo.diff then
				return "]c"
			end
			vim.schedule(gs.next_hunk)
			return "<Ignore>"
		end, "Git: Next hunk")
		map("n", "[c", function()
			if vim.wo.diff then
				return "[c"
			end
			vim.schedule(gs.prev_hunk)
			return "<Ignore>"
		end, "Git: Prev hunk")

		-- Actions
		map({ "n", "v" }, "<leader>gs", gs.stage_hunk, "Git: Stage hunk")
		map({ "n", "v" }, "<leader>gr", gs.reset_hunk, "Git: Reset hunk")
		map("n", "<leader>gS", gs.stage_buffer, "Git: Stage buffer")
		map("n", "<leader>gu", gs.undo_stage_hunk, "Git: Undo stage hunk")
		map("n", "<leader>gR", gs.reset_buffer, "Git: Reset buffer")
		map("n", "<leader>gp", gs.preview_hunk, "Git: Preview hunk")
		map("n", "<leader>gb", function()
			gs.blame_line({ full = true })
		end, "Git: Blame line")
		map("n", "<leader>gd", gs.diffthis, "Git: Diff this")
	end,
})
