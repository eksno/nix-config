-- Fallback: auto-configure any monitor not explicitly listed.
hl.monitor({ output = "", mode = "preferred", position = "auto", scale = 1 })

-- Mirror topology (glasses-as-source, VG258-as-source) is applied imperatively
-- by glasses-mirror-watcher.sh, wired in breezy.lua. Static monitor rules
-- can't do it: Hyprland is last-match-wins and a mirror rule whose target is
-- ABSENT clobbers the output to standalone instead of falling through, so
-- "mirror VG258 if present, else mirror glasses" is impossible to express here.
-- The watcher runs at session start and on every monitor hotplug.
--
-- Baseline so the laptop is sane before/without the watcher:
hl.monitor({ output = "eDP-1", mode = "2880x1800@120", position = "0x0", scale = 1.25 })
