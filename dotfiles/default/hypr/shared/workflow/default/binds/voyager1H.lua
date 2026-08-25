-- NOTE: not referenced by any user config as of the .conf -> lua migration.
-- Kept for reference; wire it up with require("shared/workflow/default/binds/voyager1H").

local mainMod = "ALT"

-- TODO: Change all binds to qwerty compatible binds
hl.bind(mainMod .. " + Q", hl.dsp.exec_cmd("kitty"))
hl.bind(mainMod .. " + W", hl.dsp.window.close())
hl.bind(mainMod .. " + E", hl.dsp.exec_cmd("dolphin"))
hl.bind(mainMod .. " + V", hl.dsp.window.float({ action = "toggle" }))
-- The .conf wrote this as `$mainMod_L`, which hyprlang read as an undefined
-- variable named "mainMod_L". The intent is the left ALT key.
hl.bind("ALT + ALT_L",
  hl.dsp.exec_cmd([[pkill tofi-run || $(tofi-run --font /usr/share/fonts/noto/NotoSansMono-Regular.ttf)]]),
  { release = true })
hl.bind(mainMod .. " + P", hl.dsp.window.pseudo())         -- dwindle
hl.bind(mainMod .. " + J", hl.dsp.layout("togglesplit"))   -- dwindle
hl.bind(mainMod .. " + k", hl.dsp.exec_cmd([[grim -g "$(slurp)" - | wl-copy]]))

-- Move focus with mainMod + arrow keys
hl.bind(mainMod .. " + left",  hl.dsp.focus({ direction = "left" }))
hl.bind(mainMod .. " + right", hl.dsp.focus({ direction = "right" }))
-- The .conf had an empty direction here ("movefocus, " with no arg); "up" is
-- the evident intent given the surrounding binds.
hl.bind(mainMod .. " + up",    hl.dsp.focus({ direction = "up" }))
hl.bind(mainMod .. " + down",  hl.dsp.focus({ direction = "down" }))

-- Switch/move workspaces
local workspaceKeys = {
  "a", "o", "e", "i", "u", "d", -- 1-6
  "h", "t", "n", "s",           -- 7-10 (dev)
  "c", "l", "r", "g",           -- 11-14
}

for i, key in ipairs(workspaceKeys) do
  hl.bind(mainMod .. " + " .. key,         hl.dsp.focus({ workspace = i }))
  hl.bind(mainMod .. " + SHIFT + " .. key, hl.dsp.window.move({ workspace = i }))
end

-- Scroll through existing workspaces with mainMod + scroll
hl.bind(mainMod .. " + mouse_down", hl.dsp.focus({ workspace = "e+1" }))
hl.bind(mainMod .. " + mouse_up",   hl.dsp.focus({ workspace = "e-1" }))

-- Move/resize windows with mainMod + LMB/RMB and dragging
hl.bind(mainMod .. " + mouse:272", hl.dsp.window.drag(),   { mouse = true })
hl.bind(mainMod .. " + mouse:273", hl.dsp.window.resize(), { mouse = true })
