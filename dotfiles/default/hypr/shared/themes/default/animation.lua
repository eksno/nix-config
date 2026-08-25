hl.config({ animations = { enabled = true } })

-- █▄▄ █▀▀ ▀█ █ █▀▀ █▀█   █▀▀ █ █ █▀█ █ █ █▀▀
-- █▄█ ██▄ █▄ █ ██▄ █▀▄   █▄▄ █▄█ █▀▄ ▀▄▀ ██▄
hl.curve("wind",   { type = "bezier", points = { { 0.05, 0.9 },  { 0.1, 1.05 } } })
hl.curve("winIn",  { type = "bezier", points = { { 0.1,  1.1 },  { 0.1, 1.1  } } })
hl.curve("winOut", { type = "bezier", points = { { 0.3, -0.3 },  { 0,   1    } } })
hl.curve("liner",  { type = "bezier", points = { { 1,    1   },  { 1,   1    } } })
-- Snappy: easeOutExpo. Motion is distributed across the whole duration with a
-- visible deceleration tail that lands cleanly at 1.0 — eye sees
-- fast→decel→stop within the same window. Avoids the "drifted after it looked
-- done" feel of more aggressively front-loaded curves.
hl.curve("snap",   { type = "bezier", points = { { 0.16, 1   },  { 0.3, 1    } } })

-- ▄▀█ █▄ █ █ █▀▄▀█ ▄▀█ ▀█▀ █ █▀█ █▄ █
-- █▀█ █ ▀█ █ █ ▀ █ █▀█  █  █ █▄█ █ ▀█
hl.animation({ leaf = "windows",     enabled = true, speed = 6,  bezier = "wind",   style = "slide" })
hl.animation({ leaf = "windowsIn",   enabled = true, speed = 6,  bezier = "winIn",  style = "slide" })
hl.animation({ leaf = "windowsOut",  enabled = true, speed = 5,  bezier = "winOut", style = "slide" })
hl.animation({ leaf = "windowsMove", enabled = true, speed = 5,  bezier = "wind",   style = "slide" })
hl.animation({ leaf = "border",      enabled = true, speed = 1,  bezier = "liner" })
hl.animation({ leaf = "borderangle", enabled = true, speed = 30, bezier = "liner",  style = "loop" })
hl.animation({ leaf = "fade",        enabled = true, speed = 10, bezier = "default" })
hl.animation({ leaf = "workspaces",  enabled = true, speed = 1,  bezier = "snap",   style = "slide" })
