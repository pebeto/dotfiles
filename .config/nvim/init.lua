require("packer").startup({
	function()
		use("wbthomason/packer.nvim")
		use("lewis6991/impatient.nvim")

		-- LSP
		use("williamboman/mason.nvim")
		use("williamboman/mason-lspconfig")
		use("neovim/nvim-lspconfig")
		use("hrsh7th/cmp-nvim-lsp")
		use("hrsh7th/cmp-buffer")
		use("hrsh7th/cmp-path")
		use("hrsh7th/cmp-cmdline")
		use("hrsh7th/nvim-cmp")
		use("L3MON4D3/LuaSnip")
		use("saadparwaiz1/cmp_luasnip")
		use("rafamadriz/friendly-snippets")
		use("j-hui/fidget.nvim")
		use({
			"glepnir/lspsaga.nvim",
			branch = "main",
			config = function()
				require("lspsaga").setup({})
			end,
			requires = { { "nvim-tree/nvim-web-devicons" } },
		})
		use({ "jose-elias-alvarez/null-ls.nvim", requires = { { "nvim-lua/plenary.nvim" } } })

		-- File utils
		use({ "ms-jpq/chadtree", branch = "chad", run = "python3 -m chadtree deps" })
		use({ "nvim-telescope/telescope.nvim", requires = { { "nvim-lua/plenary.nvim" } } })
		use("akinsho/toggleterm.nvim")

		-- Git
		use("lewis6991/gitsigns.nvim")
		use({ "sindrets/diffview.nvim", requires = "nvim-lua/plenary.nvim" })

		-- Utils
		use({
			"numToStr/Comment.nvim",
			config = function()
				require("Comment").setup()
			end,
		})
		use("windwp/nvim-ts-autotag")
		use("windwp/nvim-autopairs")
		use({
			"ellisonleao/glow.nvim",
			config = function()
				require("glow").setup()
			end,
		})
		use("tpope/vim-surround")
		use({
			"folke/trouble.nvim",
			requires = "kyazdani42/nvim-web-devicons",
			config = function()
				require("trouble").setup({})
			end,
		})
		use({ "shortcuts/no-neck-pain.nvim", tag = "*" })
		use({ "JuliaEditorSupport/julia-vim" })
		use({ "Vigemus/iron.nvim" })
		use({
			"zbirenbaum/copilot.lua",
			cmd = "Copilot",
			event = "InsertEnter",
			config = function()
				require("copilot").setup({
					panel = { auto_refresh = true },
					suggestion = { auto_trigger = true },
					filetypes = { markdown = true },
				})
			end,
		})
		use({
			"nvim-neorg/neorg",
			config = function()
				require("neorg").setup({
					load = {
						["core.defaults"] = {}, -- Loads default behaviour
						["core.concealer"] = {}, -- Adds pretty icons to your documents
						["core.dirman"] = { -- Manages Neorg workspaces
							config = {
								workspaces = {
									work = "~/notes/work",
									home = "~/notes/home",
									study = "~/notes/study",
									gsoc = "~/notes/gsoc",
								},
							},
						},
					},
				})
			end,
			run = ":Neorg sync-parsers",
			requires = "nvim-lua/plenary.nvim",
		})

		-- Eyecandy
		use({ "nvim-treesitter/nvim-treesitter", run = ":TSUpdate" })
		-- use({ "kdheepak/monochrome.nvim" })
		use("rebelot/kanagawa.nvim")

		use("rcarriga/nvim-notify")

		use("lukas-reineke/indent-blankline.nvim")
		use({
			"nvim-lualine/lualine.nvim",
			requires = { "kyazdani42/nvim-web-devicons", opt = true },
		})
		use("andweeb/presence.nvim")
		use("kyazdani42/nvim-web-devicons")
		use("petertriho/nvim-scrollbar")
		use({
			"utilyre/barbecue.nvim",
			tag = "*",
			requires = {
				"SmiteshP/nvim-navic",
				"nvim-tree/nvim-web-devicons", -- optional dependency
			},
			after = "nvim-web-devicons", -- keep this if you're using NvChad
			config = function()
				require("barbecue").setup({ create_autocmd = false })
			end,
		})
		use({
			"jcdickinson/wpm.nvim",
			config = function()
				require("wpm").setup({})
			end,
		})
		use({
			"folke/todo-comments.nvim",
			requires = "nvim-lua/plenary.nvim",
			config = function()
				require("todo-comments").setup()
			end,
		})
	end,
	config = { git = { clone_timeout = 360 } },
})

require("impatient")

require("nvim-web-devicons").setup()
require("nvim-ts-autotag").setup()
require("nvim-autopairs").setup({})
require("Comment").setup()
require("scrollbar").setup()
require("gitsigns").setup()
require("fidget").setup()

-- Colorscheme
vim.opt.termguicolors = true
-- vim.cmd("colorscheme monochrome")
vim.cmd("colorscheme kanagawa-lotus")

require("plugins.lsp-definition")
require("plugins.iron-definition")
require("plugins.lualine-definition")
require("plugins.null_ls-definition")
require("plugins.chadtree-definition")
require("plugins.gitsigns-definition")
require("plugins.telescope-definition")
require("plugins.treesitter-definition")
require("plugins.toggleterm-definition")
require("plugins.indent-blankline-definition")

-- General configuration
vim.opt.cursorline = true

vim.opt.number = true
vim.opt.hlsearch = true

vim.opt.tabstop = 4
vim.opt.shiftwidth = 4
vim.opt.smartindent = true
vim.opt.expandtab = true
vim.opt.autoread = true

vim.notify = require("notify")
