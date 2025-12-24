local cmp = require("blink.cmp")

cmp.setup({
    keymap = { preset = "default" },
    appearance = {
        nerd_font_variant = "mono",
    },
    completion = {
        documentation = {
            auto_show = false,
            window = { border = "single" },
        },
    },
    signature = { window = { border = "single" } },
    sources = {
        default = { "lsp", "path", "buffer" },
    },
    fuzzy = { implementation = "prefer_rust_with_warning" },
})
