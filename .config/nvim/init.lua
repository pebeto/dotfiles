-- Bootstrap lazy.nvim
local lazypath = vim.fn.stdpath("data") .. "/lazy/lazy.nvim"
if not vim.uv.fs_stat(lazypath) then
    vim.fn.system({
        "git",
        "clone",
        "--filter=blob:none",
        "https://github.com/folke/lazy.nvim.git",
        "--branch=stable",
        lazypath,
    })
end
vim.opt.rtp:prepend(lazypath)

-- Plugin specifications
require("lazy").setup({
    -- Core
    { "nvim-treesitter/nvim-treesitter" },

    -- LSP
    {
        "mason-org/mason-lspconfig.nvim",
        opts = { servers = { lua_ls = {} } },
        dependencies = {
            { "mason-org/mason.nvim", opts = {} },
            { "neovim/nvim-lspconfig" },
        },
    },
    { "stevearc/conform.nvim", opts = {} },
    { "mfussenegger/nvim-lint" },
    -- LSP progress UI (so SymbolServer.jl indexing etc. is visible).
    { "j-hui/fidget.nvim", opts = {} },

    -- UI / Navigation
    {
        "stevearc/oil.nvim",
        opts = {},
        dependencies = {
            { "nvim-mini/mini.icons", opts = {} },
            { "malewicz1337/oil-git.nvim" },
            { "JezerM/oil-lsp-diagnostics.nvim", opts = {} },
        },
        lazy = false,
    },
    {
        "nvim-telescope/telescope.nvim",
        version = "*",
        dependencies = {
            "nvim-lua/plenary.nvim",
            { "nvim-telescope/telescope-fzf-native.nvim", build = "make" },
        },
    },

    -- Productivity
    { "akinsho/toggleterm.nvim" },
    { "lewis6991/gitsigns.nvim" },
    { "windwp/nvim-ts-autotag", opts = {} },
    { "windwp/nvim-autopairs", opts = {} },
    { "kylechui/nvim-surround", opts = {} },
    { "JuliaEditorSupport/julia-vim" },
    { "rafamadriz/friendly-snippets" },
    {
        "saghen/blink.cmp",
        version = "*",
        opts = {
            keymap = { preset = "default" },
            sources = {
                default = { "lsp", "buffer", "snippets", "path" },
            },
            snippets = { preset = "default" },
            completion = {
                documentation = { auto_show = true, auto_show_delay_ms = 200 },
                ghost_text = { enabled = true },
            },
        },
    },
    {
        "MeanderingProgrammer/render-markdown.nvim",
        dependencies = { "nvim-mini/mini.icons" },
        opts = {},
    },

    -- AI
    {
        "zbirenbaum/copilot.lua",
        cmd = "Copilot",
        event = "InsertEnter",
        opts = {
            panel = { auto_refresh = true },
            -- Inline ghost text + cycling (<M-]> / <M-[>) handled by copilot
            -- natively; blink owns LSP/buffer/snippets/path.
            suggestion = { auto_trigger = true },
            filetypes = { markdown = true },
        },
    },

    -- Custom
    { "pebeto/dookie.nvim" },
    { "rcarriga/nvim-notify" },
    { "nvim-mini/mini.icons" },
    { "Bekaboo/deadcolumn.nvim" },

    -- UX helpers
    {
        "folke/which-key.nvim",
        event = "VeryLazy",
        init = function()
            vim.o.timeout = true
            vim.o.timeoutlen = 300
        end,
        opts = {},
    },
    {
        "nvim-orgmode/orgmode",
        event = "VeryLazy",
        ft = { "org" },
        dependencies = { "nvim-orgmode/org-bullets.nvim" },
    },
})

-- Load user configuration
require("config.options")
require("plugins.lsp")
require("plugins.conform")
require("plugins.lint")
require("plugins.oil")
require("plugins.gitsigns")
require("plugins.telescope")
require("plugins.toggleterm")
require("plugins.extras")
