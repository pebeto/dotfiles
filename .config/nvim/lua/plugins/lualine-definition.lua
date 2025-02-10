require("lualine").setup({
    options = {
        theme = "auto",
        component_separators = "",
        section_separators = { left = "", right = "" },
    },
    sections = {
        lualine_a = {
            { "mode", right_padding = 2 },
        },
        lualine_b = {
            "branch",
            {
                "filename",
                path = 3,
            },
        },
        lualine_c = { "fileformat" },
        lualine_x = { "encoding" },
        lualine_y = { "filetype", "progress" },
        lualine_z = { "location" },
    },
    inactive_sections = {
        lualine_a = { "filename" },
        lualine_b = {},
        lualine_c = {},
        lualine_x = {},
        lualine_y = {},
        lualine_z = { "location" },
    },
    tabline = {},
    extensions = {'chadtree', 'toggleterm'},
})
