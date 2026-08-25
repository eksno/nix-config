-- █▀▀ █▀▀ █▄ █ █▀▀ █▀█ ▄▀█ █
-- █▄█ ██▄ █ ▀█ ██▄ █▀▄ █▀█ █▄▄

local neptune = require("shared/colors/startino-neptune")

hl.config({
  general = {
    gaps_in     = 0,
    gaps_out    = 0,
    border_size = 0,
    col = {
      active_border   = { colors = { neptune.active_border_a, neptune.active_border_b }, angle = 45 },
      inactive_border = neptune.inactive_border,
    },
    layout = "dwindle",
    -- cursor_inactive_timeout = 0
    -- no_focus_fallback = false
    -- resize_on_border = false
  },
})
