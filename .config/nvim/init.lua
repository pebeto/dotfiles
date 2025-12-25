local lazypath = vim.fn.stdpath("data") .. "/lazy/lazy.nvim"
if not vim.loop.fs_stat(lazypath) then
    vim.fn.system({
        "git",
        "clone",
        "--filter=blob:none",
        "https://github.com/folke/lazy.nvim.git",
        "--branch=stable", -- latest stable release
        lazypath,
    })
end
vim.opt.rtp:prepend(lazypath)

local plugins = {
    {
        "nvim-treesitter/nvim-treesitter",
        build = ":TSUpdate",
    },
    {
        "mason-org/mason-lspconfig.nvim",
        opts = {
            servers = {
                lua_ls = {},
            },
        },
        dependencies = {
            { "mason-org/mason.nvim", opts = {} },
            {
                "neovim/nvim-lspconfig",
                dependencies = {
                    {
                        "saghen/blink.cmp",
                        version = "1.*",
                    },
                },
            },
        },
    },
    {
        "nvimdev/lspsaga.nvim",
        config = function()
            require("lspsaga").setup({
                lightbulb = {
                    virtual_text = false,
                },
            })
        end,
        dependencies = {
            "nvim-treesitter/nvim-treesitter",
            "nvim-tree/nvim-web-devicons",
        },
    },
    {
        "creativenull/efmls-configs-nvim",
        dependencies = { "neovim/nvim-lspconfig" },
    },
    {
        "nvim-neo-tree/neo-tree.nvim",
        branch = "v3.x",
        dependencies = {
            "nvim-lua/plenary.nvim",
            "nvim-tree/nvim-web-devicons",
            "MunifTanjim/nui.nvim",
        },
    },
    {
        "nvim-telescope/telescope.nvim",
        tag = "0.1.5",
        dependencies = { "nvim-lua/plenary.nvim" },
    },
    "akinsho/toggleterm.nvim",
    "lewis6991/gitsigns.nvim",
    {
        "sindrets/diffview.nvim",
        dependencies = {
            "nvim-lua/plenary.nvim",
        },
    },
    "windwp/nvim-ts-autotag",
    "windwp/nvim-autopairs",
    "kylechui/nvim-surround",
    "JuliaEditorSupport/julia-vim",
    {
        "zbirenbaum/copilot.lua",
        cmd = "Copilot",
        event = "InsertEnter",
        config = function()
            require("copilot").setup({
                panel = {
                    auto_refresh = true,
                },
                suggestion = {
                    auto_trigger = true,
                },
                filetypes = {
                    markdown = true,
                },
            })
        end,
    },
    "pebeto/dookie.nvim",
    {
        "rcarriga/nvim-notify",
        config = function()
            vim.notify = require("notify").setup({
                fps = 60,
                stages = "slide",
                render = "wrapped-compact",
            })
        end,
    },
    "kyazdani42/nvim-web-devicons",
    "Bekaboo/deadcolumn.nvim",
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
        config = function()
            local org = require("orgmode")

            org.setup({
                org_agenda_files = "~/Sync/orgfiles/**/*",
                org_default_notes_file = "~/Sync/orgfiles/refile.org",
            })
        end,
    },
}
require("lazy").setup(plugins)

require("config")

require("plugins.lsp-definition")
require("plugins.efmls-definition")
require("plugins.cmp-definition")
require("plugins.neotree-definition")
require("plugins.gitsigns-definition")
require("plugins.telescope-definition")
require("plugins.treesitter-definition")
require("plugins.toggleterm-definition")
