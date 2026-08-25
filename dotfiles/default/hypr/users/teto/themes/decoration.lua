hl.config({
  decoration = {
    -- █▀█ █▀█ █ █ █▄ █ █▀▄   █▀▀ █▀█ █▀█ █▄ █ █▀▀ █▀█
    -- █▀▄ █▄█ █▄█ █ ▀█ █▄▀   █▄▄ █▄█ █▀▄ █ ▀█ ██▄ █▀▄
    rounding = 0,

    -- █▀█ █▀█ ▄▀█ █▀▀ █ ▀█▀ █▄█
    -- █▄█ █▀▀ █▀█ █▄▄ █  █   █
    active_opacity   = 1.0,
    inactive_opacity = 1.0,

    -- █▄▄ █   █ █ █▀█
    -- █▄█ █▄▄ █▄█ █▀▄
    blur = {
      enabled           = false,
      size              = 6,
      passes            = 3,
      new_optimizations = true,
      xray              = true,
      ignore_opacity    = true,
    },

    -- █▀ █ █ ▄▀█ █▀▄ █▀█ █ █ █
    -- ▄█ █▀█ █▀█ █▄▀ █▄█ ▀▄▀▄▀
    -- Migrated from the flat drop_shadow/shadow_* keys, all removed upstream.
    -- NOTE: `shadow_ignore_window` has no replacement in the shadow block and
    -- is dropped.
    shadow = {
      enabled      = false,
      offset       = { 1, 2 },
      range        = 10,
      render_power = 5,
      color        = 0x66404040,
    },
  },
})

-- `blurls = <namespace>` became layer rules.
-- hl.layer_rule({ match = { namespace = "gtk-layer-shell" }, blur = true })
hl.layer_rule({ match = { namespace = "waybar" },     blur = true })
hl.layer_rule({ match = { namespace = "lockscreen" }, blur = true })
