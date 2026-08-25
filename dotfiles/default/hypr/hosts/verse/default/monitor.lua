-- 120hz
-- hl.monitor({ output = "eDP-1", mode = "modeline 934.00 2880 3136 3456 4032 1800 1803 1809 1931 -hsync +vsync", position = "0x0", scale = 1 })
-- 60hz
hl.monitor({
  output   = "eDP-1",
  mode     = "modeline 442.00 2880 3104 3416 3952 1800 1803 1809 1865 -hsync +vsync",
  position = "0x0",
  scale    = 2,
})

-- When the TV is connected it is the primary picture at native 4K60
-- (preferred/auto picks its broken 30Hz EDID default), and the laptop panel
-- mirrors it. The TV's 16:9 wins; the laptop gets the letterbox.
hl.monitor({ output = "HDMI-A-1", mode = "3840x2160@60", position = "auto", scale = 1.5 })
hl.monitor({ output = "eDP-1", mode = "2880x1800@60", position = "auto", scale = 2, mirror = "HDMI-A-1" })
