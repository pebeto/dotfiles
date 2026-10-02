-- [count]<leader>t toggles a terminal split, so 2<leader>t is a second, independent one.
-- Hiding keeps the shell running, and the split comes back at the height you left it.
-- Neovim already hides line numbers in terminals and closes the buffer when the shell
-- exits cleanly.
local terms = {}

local function toggle(n)
    local t = terms[n]
    if t and t.win and vim.api.nvim_win_is_valid(t.win) then
        t.height = vim.api.nvim_win_get_height(t.win)
        -- Fails only when the terminal is the last window, where hiding has nowhere to go.
        if pcall(vim.api.nvim_win_hide, t.win) then
            t.win = nil
        end
        return
    end
    vim.cmd(("botright %dsplit"):format(t and t.height or 15))
    if t and vim.api.nvim_buf_is_valid(t.buf) then
        vim.api.nvim_win_set_buf(0, t.buf)
    else
        vim.cmd.terminal()
        t = { buf = vim.api.nvim_get_current_buf() }
        terms[n] = t
    end
    t.win = vim.api.nvim_get_current_win()
    vim.cmd.startinsert()
end

vim.keymap.set("n", "<leader>t", function()
    toggle(vim.v.count1)
end, { desc = "Toggle terminal" })

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
