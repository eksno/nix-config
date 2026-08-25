-- █▀▀ ▀▄▀ █▀▀ █▀▀
-- ██▄ █ █ ██▄ █▄▄
hl.on("hyprland.start", function()
  -- hl.exec_cmd("eww")
  -- hl.exec_cmd("swww init")

  hl.exec_cmd("steam steam://rungameid/1147690", { workspace = "7" })

  hl.exec_cmd("spotify",        { workspace = "1 silent" })
  hl.exec_cmd("helvum",         { workspace = "1 silent" }) -- whatever music program here too
  hl.exec_cmd("webcord",        { workspace = "2 silent" })
  hl.exec_cmd("signal-desktop", { workspace = "3 silent" })
  hl.exec_cmd("brave https://configure.zsa.io/my_layout/view/7q6Nx", { workspace = "5 silent" })
  -- hl.exec_cmd("caprine",  { workspace = "3 silent" })
  -- hl.exec_cmd("obsidian", { workspace = "4 silent" })
  -- hl.exec_cmd("firefox",  { workspace = "4 silent" })
  -- hl.exec_cmd("firefox",  { workspace = "7" })
  -- hl.exec_cmd("firefox",  { workspace = "8 silent" })
  hl.exec_cmd("firefox", { workspace = "9 silent" })
  hl.exec_cmd("kitty",   { workspace = "10 silent" })
end)
