hl.config({
  general = {
    layout = "dwindle",
  },

  dwindle = {
    -- `pseudotile` and `no_gaps_when_only` were removed upstream (0.55).
    -- Pseudotiling is now only the `pseudo` dispatcher; "no gaps when only"
    -- is expressed with workspace rules (see shared/utility/workspace.lua).
    force_split                 = 0,
    preserve_split              = false,
    smart_split                 = false,
    smart_resizing              = true,
    permanent_direction_override = false,
    special_scale_factor        = 1,
    split_width_multiplier      = 1.0,
    use_active_for_splits       = true,
    default_split_ratio         = 1.0,
  },
})
