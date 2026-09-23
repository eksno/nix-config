-- Matches the keymap in shared/workflow/default/binds/dvp.lua.
local mainMod = "SUPER"

-- Toggle waybar
hl.bind(mainMod .. " + b", hl.dsp.exec_cmd("pkill -SIGUSR1 waybar || waybar &"))

hl.on("hyprland.start", function()
  -- System
  hl.exec_cmd("waybar")

  -- Programs
  hl.exec_cmd("kitty", { workspace = "9" })
  hl.exec_cmd("discord")
  hl.exec_cmd("protonvpn-app", { workspace = "16 silent" })
end)

-- Window rules
hl.window_rule({
  name  = "discord-to-ws2",
  match = { class = "discord" },
  workspace = "2 silent",
})
