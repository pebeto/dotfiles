-- Parsers for the languages the LSP, formatter and linter setup covers. Neovim bundles
-- c, lua, markdown, query, vim and vimdoc; c is installed anyway because cpp's queries
-- inherit from it, and the two must come from the same place.
local parsers = {
    "bash",
    "c",
    "cpp",
    "css",
    "diff",
    "dockerfile",
    "gitcommit",
    "html",
    "javascript",
    "json",
    "julia",
    "latex",
    "python",
    "toml",
    "tsx",
    "typescript",
    "yaml",
}

-- Asynchronous, and a no-op for parsers already installed.
require("nvim-treesitter").install(parsers)

local filetypes = {}
for _, lang in ipairs(parsers) do
    vim.list_extend(filetypes, vim.treesitter.language.get_filetypes(lang))
end

-- The plugin installs parsers but never turns highlighting on; Neovim does that.
vim.api.nvim_create_autocmd("FileType", {
    pattern = filetypes,
    callback = function(ev)
        -- On the first launch the parser may still be compiling.
        if not pcall(vim.treesitter.start, ev.buf) then
            return
        end
        -- start() turns regex syntax off, and julia-vim's indenter reads syntax groups.
        if ev.match == "julia" then
            vim.bo[ev.buf].syntax = "ON"
        end
    end,
})
