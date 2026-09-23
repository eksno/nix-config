local mainMod = "SUPER"

-- Kill active window
hl.bind(mainMod .. " + delete", hl.dsp.window.close())

-- Hyprland Functions
hl.bind(mainMod .. " + q", hl.dsp.window.float({ action = "toggle" }))
hl.bind(mainMod .. " + w", hl.dsp.window.pseudo())
hl.bind(mainMod .. " + e", hl.dsp.layout("togglesplit"))

-- Run Menu (run and eval tofi run)
hl.bind("SUPER + SUPER_L",
  hl.dsp.exec_cmd([[pkill tofi-run || $(tofi-run --font /usr/share/fonts/noto/NotoSansMono-Regular.ttf)]]),
  { release = true })

-- Screenshot — wayshot+slurp+magick because grim AND grimblast AND
-- `wayshot -g` are all broken under fractional scaling.
hl.bind(mainMod .. " + v", hl.dsp.exec_cmd("~/.config/hypr/shared/scripts/screenshot-region.sh"))

-- Move focus with mainMod + arrow keys
hl.bind(mainMod .. " + left",  hl.dsp.focus({ direction = "left" }))
hl.bind(mainMod .. " + right", hl.dsp.focus({ direction = "right" }))
hl.bind(mainMod .. " + up",    hl.dsp.focus({ direction = "up" }))
hl.bind(mainMod .. " + down",  hl.dsp.focus({ direction = "down" }))

-- ---------- --
-- Workspaces --
-- ---------- --

local workspaceKeys = {
  "a", "s", "d", "f", "g", "h", "j", "k", "l", "semicolon", -- 1-10  home row
  "u", "i", "o", "p",                                       -- 11-14 top row
  "n", "m", "comma", "period", "slash",                     -- 15-19 bottom row
}

for i, key in ipairs(workspaceKeys) do
  hl.bind(mainMod .. " + " .. key,         hl.dsp.focus({ workspace = i }))
  hl.bind(mainMod .. " + SHIFT + " .. key, hl.dsp.window.move({ workspace = i }))
end

-- Move/resize windows with mainMod + LMB/RMB and dragging
hl.bind(mainMod .. " + mouse:272", hl.dsp.window.drag(),   { mouse = true })
hl.bind(mainMod .. " + mouse:273", hl.dsp.window.resize(), { mouse = true })
