local mainMod = "SUPER"

-- Kill active window
hl.bind(mainMod .. " + delete", hl.dsp.window.close())

-- Hyprland Functions
hl.bind(mainMod .. " + period",    hl.dsp.window.float({ action = "toggle" }))
hl.bind(mainMod .. " + comma",     hl.dsp.window.pseudo())
hl.bind(mainMod .. " + semicolon", hl.dsp.layout("togglesplit"))

-- Run Menu (run and eval tofi run)
hl.bind("SUPER + SUPER_L",
  hl.dsp.exec_cmd([[pkill tofi-run || $(tofi-run --font /usr/share/fonts/noto/NotoSansMono-Regular.ttf)]]),
  { release = true })

-- ---------------- --
-- Screenshots (grim)
-- ---------------- --

-- Region screenshot -> clipboard
hl.bind(mainMod .. " + k",
  hl.dsp.exec_cmd([[sh -c "grim -g \"$(slurp)\" - | wl-copy"]]))

-- Focused monitor screenshot -> clipboard
hl.bind(mainMod .. " + SHIFT + k",
  hl.dsp.exec_cmd([[sh -c "mon=$(hyprctl monitors -j | jq -r '.[] | select(.focused==true).name'); grim -o \"$mon\" - | wl-copy"]]))

-- ---------------- --
-- Screen Recording (wl-screenrec)
-- ---------------- --

-- Region recording -> clipboard (ephemeral, no file saved)
hl.bind(mainMod .. " + x",
  hl.dsp.exec_cmd([[sh -c "notify-send 'Recording' 'Region capture started (clipboard only)'; wl-screenrec -g \"$(slurp)\" -o - | wl-copy --type=video/mp4; notify-send 'Recording' 'Region capture copied to clipboard'"]]))

-- Focused monitor recording -> clipboard (ephemeral, no file saved)
hl.bind(mainMod .. " + SHIFT + x",
  hl.dsp.exec_cmd([[sh -c "mon=$(hyprctl monitors -j | jq -r '.[] | select(.focused==true).name'); notify-send 'Recording' \"Monitor $mon capture started (clipboard only)\"; wl-screenrec -o \"$mon\" - | wl-copy --type=video/mp4; notify-send 'Recording' \"Monitor $mon capture copied to clipboard\""]]))

-- Stop recording
hl.bind(mainMod .. " + CTRL + x",
  hl.dsp.exec_cmd([[sh -c "pkill -INT wl-screenrec && notify-send 'Recording' 'Stopped'"]]))

-- Move focus with mainMod + arrow keys
hl.bind(mainMod .. " + left",  hl.dsp.focus({ direction = "left" }))
hl.bind(mainMod .. " + right", hl.dsp.focus({ direction = "right" }))
hl.bind(mainMod .. " + up",    hl.dsp.focus({ direction = "up" }))
hl.bind(mainMod .. " + down",  hl.dsp.focus({ direction = "down" }))

-- ---------- --
-- Workspaces --
-- ---------- --

-- Home Row / Top Row / Bottom Row, in Programmer Dvorak order.
local workspaceKeys = {
  "a", "o", "e", "u", "i", "d", "h", "t", "n", "s", -- 1-10  home row
  "g", "c", "r", "l",                               -- 11-14 top row
  "m", "w", "v", "z",                               -- 15-18 bottom row
}

for i, key in ipairs(workspaceKeys) do
  hl.bind(mainMod .. " + " .. key,             hl.dsp.focus({ workspace = i }))
  hl.bind(mainMod .. " + SHIFT + " .. key,     hl.dsp.window.move({ workspace = i }))
end

-- Move/resize windows with mainMod + LMB/RMB and dragging
hl.bind(mainMod .. " + mouse:272", hl.dsp.window.drag(),   { mouse = true })
hl.bind(mainMod .. " + mouse:273", hl.dsp.window.resize(), { mouse = true })
