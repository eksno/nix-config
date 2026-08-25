-- Norwegian letters on a US layout. norwegian-type.sh routes to the right
-- backend per app: wtype for native Wayland (terminals, Zen, GTK), and
-- wl-copy + Ctrl+V through ydotool/uinput for Electron/Chromium clients
-- that ignore virtual_keyboard_unstable_v1.
local typer = "~/.config/hypr/users/eksno/default/norwegian-type.sh"

hl.bind("ALT + a",         hl.dsp.exec_cmd(typer .. " å"))
hl.bind("ALT + SHIFT + a", hl.dsp.exec_cmd(typer .. " Å"))
hl.bind("ALT + o",         hl.dsp.exec_cmd(typer .. " ø"))
hl.bind("ALT + SHIFT + o", hl.dsp.exec_cmd(typer .. " Ø"))
hl.bind("ALT + e",         hl.dsp.exec_cmd(typer .. " æ"))
hl.bind("ALT + SHIFT + e", hl.dsp.exec_cmd(typer .. " Æ"))
