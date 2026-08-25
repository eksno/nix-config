-- Make tofi appear instantly: skip the global fade animation on its
-- layer-shell surface.
-- Note: tofi sets its layer-shell namespace to "launcher" (hardcoded in
-- tofi src/main.c → zwlr_layer_shell_v1_get_layer_surface(..., "launcher")),
-- NOT "tofi". Match on that string.
hl.layer_rule({
  name    = "launcher-no-anim",
  match   = { namespace = "^(launcher)$" },
  no_anim = true,
})

-- Toucan keyboard cheatsheet (eww). no_anim avoids fade-in flicker.
-- ignore_alpha here is a blur optimization (skips blur on transparent pixels)
-- — Hyprland has no input-passthrough rule for layers, so pointer
-- click-through has to be handled elsewhere.
hl.layer_rule({
  name         = "kbd-cheatsheet-ignore-alpha",
  match        = { namespace = "^(kbd-cheatsheet)$" },
  ignore_alpha = 0.5,
})
hl.layer_rule({
  name    = "kbd-cheatsheet-no-anim",
  match   = { namespace = "^(kbd-cheatsheet)$" },
  no_anim = true,
})
