hl.on("hyprland.start", function()
  hl.exec_cmd("spotify", { workspace = "1 silent" })
  hl.exec_cmd("webcord", { workspace = "2 silent" })
  hl.exec_cmd("caprine", { workspace = "3 silent" })
  -- hl.exec_cmd("obsidian", { workspace = "4 silent" })
  hl.exec_cmd("brave",   { workspace = "6 silent" })
end)

-- -- For VNC
-- hl.exec_cmd("set WLR_BACKENDS headless && set WLR_LIBINPUT_NO_DEVICES 1 && Hyprland & WAYLAND_DISPLAY=wayland-1 wayvnc -C ~/uwu-pics/conf -g -L trace", { workspace = "15 silent" })
