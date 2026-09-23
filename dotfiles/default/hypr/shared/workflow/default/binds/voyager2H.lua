local mainMod = "SUPER"

local dashboard = "bash ~/.config/eww/dashboard/launch_dashboard"

-- Kill active window
hl.bind(mainMod .. " + delete", hl.dsp.window.close())

hl.bind("SUPER + X", hl.dsp.exec_cmd(dashboard))

-- Hyprland Functions
hl.bind(mainMod .. " + period", hl.dsp.window.float({ action = "toggle" }))
hl.bind(mainMod .. " + comma",  hl.dsp.window.pseudo())
-- NOTE: the bare `togglesplit` dispatcher was removed in Hyprland 0.55; it now
-- lives under layoutmsg (hl.dsp.layout).
hl.bind(mainMod .. " + y",      hl.dsp.layout("togglesplit"))

-- Run Menu (run and eval tofi run)
hl.bind("SUPER + SUPER_L",
  hl.dsp.exec_cmd([[pkill tofi-run || $(tofi-run --font /usr/share/fonts/noto/NotoSansMono-Regular.ttf)]]),
  { release = true })

-- Screenshot
hl.bind(mainMod .. " + k", hl.dsp.exec_cmd([[grim -g "$(slurp)" - | wl-copy]]))

-- Move focus with mainMod + arrow keys
hl.bind(mainMod .. " + left",  hl.dsp.focus({ direction = "left" }))
hl.bind(mainMod .. " + right", hl.dsp.focus({ direction = "right" }))
hl.bind(mainMod .. " + up",    hl.dsp.focus({ direction = "up" }))
hl.bind(mainMod .. " + down",  hl.dsp.focus({ direction = "down" }))

-- ---------- --
-- Workspaces --
-- ---------- --

local workspaceKeys = {
  "a", "o", "e", "i", "u", "d", "h", "t", "n", "s", -- 1-10  home row
  "c", "l", "r", "g",                               -- 11-14 top row
  "m", "w", "v", "z",                               -- 15-18 bottom row
}

for i, key in ipairs(workspaceKeys) do
  hl.bind(mainMod .. " + " .. key,         hl.dsp.focus({ workspace = i }))
  hl.bind(mainMod .. " + SHIFT + " .. key, hl.dsp.window.move({ workspace = i }))
end

-- Move/resize windows with mainMod + LMB/RMB and dragging
hl.bind(mainMod .. " + mouse:272", hl.dsp.window.drag(),   { mouse = true })
hl.bind(mainMod .. " + mouse:273", hl.dsp.window.resize(), { mouse = true })

-- Media keys
hl.bind("XF86AudioRaiseVolume", hl.dsp.exec_cmd("wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%+"), { locked = true, repeating = true })
hl.bind("XF86AudioLowerVolume", hl.dsp.exec_cmd("wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%-"), { locked = true, repeating = true })
hl.bind("XF86AudioMute",        hl.dsp.exec_cmd("wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle"), { locked = true })
-- Requires playerctl
hl.bind("XF86AudioPlay", hl.dsp.exec_cmd("playerctl play-pause"), { locked = true })
hl.bind("XF86AudioPrev", hl.dsp.exec_cmd("playerctl previous"),   { locked = true })
hl.bind("XF86AudioNext", hl.dsp.exec_cmd("playerctl next"),       { locked = true })
