-- Smart gaps: single tiled window fills the screen
hl.workspace_rule({ workspace = "w[tv1]", gaps_out = 0, gaps_in = 0 })
hl.workspace_rule({ workspace = "f[1]",   gaps_out = 0, gaps_in = 0 })

hl.window_rule({
  name  = "smart-gaps-tv1",
  match = { float = false, workspace = "w[tv1]" },
  border_size = 0,
  rounding    = 0,
})

hl.window_rule({
  name  = "smart-gaps-f1",
  match = { float = false, workspace = "f[1]" },
  border_size = 0,
  rounding    = 0,
})

-- The .conf version ended with bare `workspace = 1` … `workspace = 18` lines.
-- A workspace rule carrying no rules is a no-op in Hyprland, so they are not
-- carried over. Workspaces are created on demand by the binds in
-- shared/workflow/default/binds/. To genuinely keep one alive when empty, use:
--   hl.workspace_rule({ workspace = "1", persistent = true })
