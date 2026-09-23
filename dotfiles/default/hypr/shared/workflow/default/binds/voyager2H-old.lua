-- NOTE: not referenced by any user config as of the .conf -> lua migration.
-- Superseded by voyager2H.lua. Kept for reference only.

local mainMod = "SUPER"

hl.bind(mainMod .. " + Q", hl.dsp.exec_cmd("kitty"))
hl.bind(mainMod .. " + DELETE", hl.dsp.window.close())
hl.bind(mainMod .. " + X", hl.dsp.window.float({ action = "toggle" }))
-- The .conf wrote this as `$mainMod_L` (an undefined hyprlang variable);
-- the intent is the left SUPER key.
hl.bind("SUPER + SUPER_L",
  hl.dsp.exec_cmd([[pkill tofi-run || $(tofi-run --font /usr/share/fonts/noto/NotoSansMono-Regular.ttf)]]),
  { release = true })
-- NOTE: SUPER+Q is bound twice in the original (kitty above, then pseudo).
-- Preserved verbatim; the later bind wins.
hl.bind(mainMod .. " + Q", hl.dsp.window.pseudo())        -- dwindle
hl.bind(mainMod .. " + J", hl.dsp.layout("togglesplit"))  -- dwindle
hl.bind(mainMod .. " + K", hl.dsp.exec_cmd([[grim -g "$(slurp)" - | wl-copy]]))

hl.bind(mainMod .. " + left",  hl.dsp.focus({ direction = "left" }))
hl.bind(mainMod .. " + right", hl.dsp.focus({ direction = "right" }))
-- Empty direction in the .conf; "up" is the evident intent.
hl.bind(mainMod .. " + up",    hl.dsp.focus({ direction = "up" }))
hl.bind(mainMod .. " + down",  hl.dsp.focus({ direction = "down" }))

local workspaceKeys = {
  "a", "o", "e", "i", "u", "d", "h", "t", "n", "s", -- 1-10
  "c", "l", "r", "g",                               -- 11-14
  "COMMA", "PERIOD", "P", "m", "w", "v", "z",       -- 15-21
}

for i, key in ipairs(workspaceKeys) do
  hl.bind(mainMod .. " + " .. key,         hl.dsp.focus({ workspace = i }))
  hl.bind(mainMod .. " + SHIFT + " .. key, hl.dsp.window.move({ workspace = i }))
end

hl.bind(mainMod .. " + mouse_down", hl.dsp.focus({ workspace = "e+1" }))
hl.bind(mainMod .. " + mouse_up",   hl.dsp.focus({ workspace = "e-1" }))

hl.bind(mainMod .. " + mouse:272", hl.dsp.window.drag(),   { mouse = true })
hl.bind(mainMod .. " + mouse:273", hl.dsp.window.resize(), { mouse = true })
