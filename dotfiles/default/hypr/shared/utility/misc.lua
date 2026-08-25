hl.config({
  misc = {
    disable_hyprland_logo      = true,
    disable_splash_rendering   = true,
    mouse_move_enables_dpms    = true,
    vrr                        = 0,
    animate_manual_resizes     = true,
    mouse_move_focuses_monitor = true,
    enable_swallow             = true,
    swallow_regex              = "^(kitty)$",
    -- Startino Neptune base — visible when no wallpaper covers it (e.g.
    -- between workspace switches, on first boot before swww initializes, or if
    -- you stop swww). To make it actually visible all the time: `swww kill` or
    -- remove `swww init` from shared/workflow/default/startup.lua.
    -- background_color wants the 0xAARRGGBB literal form; the hex matches the
    -- RGB channels of neptune.background.
    background_color           = 0x102424,
  },
})
