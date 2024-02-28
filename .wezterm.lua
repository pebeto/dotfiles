local wezterm = require("wezterm")

local config = {}

if wezterm.configbuilder then
    config = wezterm.config_builder()
end

config.font = wezterm.font("JuliaMono Nerd Font Mono")
config.font_size = 11.0

config.color_scheme = "Grayscale (dark) (terminal.sexy)"

config.use_fancy_tab_bar = false
config.tab_bar_at_bottom = true
config.hide_tab_bar_if_only_one_tab = true
config.window_padding = {
    left = 0,
    right = 0,
    top = 0,
    bottom = 0,
}
config.window_decorations = "NONE"

config.enable_wayland = false
return config
