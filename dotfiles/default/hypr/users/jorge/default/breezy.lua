-- XR sideview (Rayneo Air 4 Pro).
--
-- Super+R: recenter pose (writes recenter_screen=true to xr-driver IPC)
local mainMod = "SUPER" -- matches shared/workflow/default/binds/qwerty.lua

hl.bind(mainMod .. " + R", hl.dsp.exec_cmd("breezy-recenter"))

-- Keep the glasses mirrored cleanly (glasses-as-source, no bars) across
-- hotplug/reboot. Applies topology at startup and re-applies on every monitor
-- add/remove event. Blocks on socat, so the single instance lives for the
-- whole session.
hl.on("hyprland.start", function()
  hl.exec_cmd("~/.config/hypr/shared/scripts/glasses-mirror-watcher.sh")
end)
