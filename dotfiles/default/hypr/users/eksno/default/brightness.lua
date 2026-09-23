-- Brightness: backlight first, then gamma once the panel is maxed.
--
-- eDP-1 on this machine is an OLED whose EDID reports 400 cd/m^2 at full
-- coverage — and `brightnessctl max` is 400, i.e. the backlight scale is
-- literally nits. That 400 is a hard physical ceiling for full-screen white
-- (OLED ABL), so past it the only lever is gamma, which lifts midtones rather
-- than raising peak white. hyprsunset caps gamma at 200%.
--
-- shared/scripts/brightness.sh stitches the two ranges into one control and
-- steps the backlight geometrically, because the scale is linear in nits while
-- perception is roughly logarithmic.
local brightness = "~/.config/hypr/shared/scripts/brightness.sh"

hl.bind("XF86MonBrightnessUp",   hl.dsp.exec_cmd(brightness .. " up"),   { repeating = true, locked = true })
hl.bind("XF86MonBrightnessDown", hl.dsp.exec_cmd(brightness .. " down"), { repeating = true, locked = true })

-- gamma-only nudges, for pushing past the backlight max without walking it up
hl.bind("SUPER + XF86MonBrightnessUp",   hl.dsp.exec_cmd("hyprctl hyprsunset gamma +10"), { repeating = true, locked = true })
hl.bind("SUPER + XF86MonBrightnessDown", hl.dsp.exec_cmd("hyprctl hyprsunset gamma -10"), { repeating = true, locked = true })

-- hyprsunset holds the gamma ramp via hyprland-ctm-control-v1, so it has to stay
-- running; gamma resets when it exits. -i = identity (no blue-light shift).
-- --gamma_max is load-bearing: the default cap is 100%, so without it every
-- `gamma +10` past 100 silently clamps.
hl.on("hyprland.start", function()
  hl.exec_cmd("hyprsunset -i --gamma_max 200 --gamma 100")
end)
