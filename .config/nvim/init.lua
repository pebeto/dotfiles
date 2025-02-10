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
	"williamboman/mason.nvim",
	"williamboman/mason-lspconfig",
	"neovim/nvim-lspconfig",
	"hrsh7th/cmp-nvim-lsp",
	"hrsh7th/cmp-buffer",
	"hrsh7th/cmp-path",
	"hrsh7th/cmp-cmdline",
	"hrsh7th/nvim-cmp",
	"L3MON4D3/LuaSnip",
	"saadparwaiz1/cmp_luasnip",
	"rafamadriz/friendly-snippets",
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
	{
		"numToStr/Comment.nvim",
		lazy = false,
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
	{
		"nvim-treesitter/nvim-treesitter",
		build = ":TSUpdate",
	},
	"YorickPeterse/vim-paper",
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
	{
		"nvim-lualine/lualine.nvim",
		dependencies = {
			"kyazdani42/nvim-web-devicons",
			lazy = true,
		},
	},
	"kyazdani42/nvim-web-devicons",
    {
        'Bekaboo/dropbar.nvim',
        config = function()
          local dropbar_api = require('dropbar.api')
          vim.keymap.set('n', '<Leader>;', dropbar_api.pick, { desc = 'Pick symbols in winbar' })
          vim.keymap.set('n', '[;', dropbar_api.goto_context_start, { desc = 'Go to start of current context' })
          vim.keymap.set('n', '];', dropbar_api.select_next_context, { desc = 'Select next context' })
        end
    },
	{
		"folke/todo-comments.nvim",
		dependencies = {
			"nvim-lua/plenary.nvim",
		},
	},
	"Bekaboo/deadcolumn.nvim",
	{ "lukas-reineke/indent-blankline.nvim", main = "ibl", opts = {} },
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
        "nvim-neorg/neorg",
        lazy = false,
        version = "*",
        config = function()
            require("neorg").setup({
                load = {
                    ["core.defaults"] = {},
                    ["core.concealer"] = {},
                    ["core.dirman"] = {
                        config = {
                            workspaces = {
                                notes = "~/Sync/notes",
                                university = "~/Sync/notes/university",
                                personal = "~/Sync/notes/personal",
                                projects = "~/Sync/notes/projects",
                            },
                            default_workspace = "notes",
                        },
                    },
                },
            })
            vim.wo.foldlevel = 99
            vim.wo.conceallevel = 2
        end,
    },
}
require("lazy").setup(plugins)

require("nvim-web-devicons").setup()
require("nvim-ts-autotag").setup()
require("nvim-autopairs").setup()
require("Comment").setup()
require("gitsigns").setup()
require("ibl").setup()

-- colorscheme
vim.opt.termguicolors = true
vim.cmd("colorscheme paper")
-- End colorscheme

require("plugins.lsp-definition")
require("plugins.lualine-definition")
require("plugins.efmls-definition")
require("plugins.neotree-definition")
require("plugins.gitsigns-definition")
require("plugins.telescope-definition")
require("plugins.treesitter-definition")
require("plugins.toggleterm-definition")

-- General configuration
vim.opt.cursorline = true

vim.opt.number = true
vim.opt.hlsearch = true

vim.opt.tabstop = 4
vim.opt.shiftwidth = 4
vim.opt.expandtab = true
vim.opt.autoread = true
vim.opt.colorcolumn = "92" -- Max line length inherited from Blue style (Julia)

vim.notify = require("notify")
