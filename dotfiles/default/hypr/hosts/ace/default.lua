-- NOTE: the .conf version sourced `hosts/biwas/default/**.conf`, a path that
-- has never existed (biwas is a *user*, not a host), so hosts/ace/default/
-- input.conf was silently never loaded. Wiring it up here, which is the
-- evident intent. In hyprlang a missing source was ignored; in Lua a missing
-- require() throws and kills the file, so the dead path could not be carried
-- over verbatim anyway.
-- ace runs GNOME/X11 rather than Hyprland, so this is effectively unused.
require("hosts/ace/default/input")
