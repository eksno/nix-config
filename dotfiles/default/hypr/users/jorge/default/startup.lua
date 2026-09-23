local mainMod = "SUPER" -- matches shared/workflow/default/binds/qwerty.lua

-- Toggle waybar
hl.bind(mainMod .. " + b", hl.dsp.exec_cmd("pkill -SIGUSR1 waybar || waybar &"))

-- Brightness (min 5%)
hl.bind("XF86MonBrightnessDown",
  hl.dsp.exec_cmd([[bash -c 'MIN=$(( $(brightnessctl max) / 20 )); brightnessctl set 5%-; [ $(brightnessctl get) -lt $MIN ] && brightnessctl set $MIN']]))
hl.bind("XF86MonBrightnessUp", hl.dsp.exec_cmd("brightnessctl set 5%+"))

-- Toucan keyboard cheatsheet (persistent overlay)
hl.bind(mainMod .. " + CTRL + x", hl.dsp.exec_cmd("eww open --toggle keyboard-cheatsheet"))

hl.on("hyprland.start", function()
  -- System
  hl.exec_cmd("waybar")
  hl.exec_cmd("eww open keyboard-cheatsheet")

  -- Startup apps
  hl.exec_cmd("kitty",                { workspace = "4" })
  hl.exec_cmd("google-chrome-stable", { workspace = "5 silent" })
  hl.exec_cmd("discord",              { workspace = "3 silent" })
end)
