require("lint").linters_by_ft = {
    python = { "flake8" },
    typescript = { "eslint" },
    javascript = { "eslint" },
    typescriptreact = { "eslint" },
    javascriptreact = { "eslint" },
    markdown = { "markdownlint" },
    lua = { "selene" },
    c = { "cpplint" },
    cpp = { "cpplint" },
    dockerfile = { "hadolint" },
}

vim.keymap.set("n", "<leader>ll", function()
    require("lint").try_lint()
end, { desc = "Run linter" })
