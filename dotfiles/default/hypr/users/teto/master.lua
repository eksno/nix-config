-- Not referenced by users/teto/default.lua; kept for reference.
hl.config({
  general = {
    layout = "master",
  },

  master = {
    -- `no_gaps_when_only` and `always_center_master` were removed upstream.
    -- "No gaps when only" is now a workspace rule (see
    -- shared/utility/workspace.lua); centering is controlled by
    -- master:slave_count_for_center_master / master:center_master_fallback.
    allow_small_split    = false,
    special_scale_factor = 1,
    mfact                = 0.55,
    new_on_top           = false,
    orientation          = "top",
    smart_resizing       = true,
    drop_at_cursor       = false,
  },
})
