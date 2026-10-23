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

  -- Startup apps. Chromium apps go through launch-retry.sh: on every login
  -- they started windowless (see FIXES.md 2026-10-20 and its 10-23 note);
  -- the script gates on session readiness and monitor-topology settle, then
  -- a watchdog kills + relaunches through Hyprland's exec (same workspace
  -- rule, passed as --ws) up to three more times, 15s/45s/120s apart.
  local retry = "~/.config/hypr/users/jorge/default/launch-retry.sh "
  hl.exec_cmd("kitty", { workspace = "4" })
  hl.exec_cmd(retry .. '--ws "5 silent" google-chrome google-chrome-stable', { workspace = "5 silent" })
  hl.exec_cmd(retry .. '--ws "3 silent" discord discord',                    { workspace = "3 silent" })
end)
