hl.window_rule({
  name  = "steam-splash-stayfocused",
  match = { title = "^()$", class = "^(steam)$" },
  stay_focused = true,
})
hl.window_rule({
  name  = "steam-splash-minsize",
  match = { title = "^()$", class = "^(steam)$" },
  min_size = { 1, 1 },
})

-- hl.config({ general = { allow_tearing = true } })
-- hl.window_rule({ match = { class = "^(deadcells)$" }, immediate = true })
