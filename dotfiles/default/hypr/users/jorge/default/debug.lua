-- Keep Hyprland's per-instance log ($XDG_RUNTIME_DIR/hypr/<sig>/hyprland.log)
-- on. Startup Chrome/Discord come up windowless on login (FIXES.md 2026-10-20);
-- with logs disabled the log stops right after startup and records no window
-- map / surface events, so there is nothing to correlate against. Remove once
-- that is fixed.
hl.config({ debug = { disable_logs = false } })
