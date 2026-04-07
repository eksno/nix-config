# Fixes Log

Chronological log of non-trivial fixes for this NixOS flake. Newest entries at the top. See `CLAUDE.md` "Log Every Fix" section for the entry format and rules.

**Before debugging a new issue, grep this file first** — a past investigation may contain the answer.

---

## 2026-04-07 — hypr-screenshot-fractional-scaling

**Symptom:** `Super+v` screenshot bind silently does nothing on the laptop's built-in display (`eDP-1`), but works fine when an external monitor is connected and used.
**Affected:** host `lewis`, user `jorge`. `dotfiles/hypr/shared/workflow/default/binds/qwerty.conf:15`. eDP-1 runs at scale **1.25** (2880x1800).
**Root cause:** Raw `grim` does not handle Hyprland fractional scaling. `grim -g "$(slurp)"` and `grim -o eDP-1` both fail with `supplied geometry did not intersect with any outputs` when the target output has a non-integer scale. External monitors at scale 1.0 are unaffected, which is why the bind appeared to "only work on the external display".
**Investigation:**
1. Confirmed active host/user: `lewis` / `jorge`. Active keymap: `qwerty.conf` (sourced from `dotfiles/hypr/users/jorge/default.conf:3`).
2. `hyprctl monitors` showed `eDP-1` at `2880x1800@120` with `scale: 1.25`.
3. Found the bind: `bind = $mainMod, v, exec, sh -c 'grim -g "$(slurp)" - | wl-copy'`.
4. Reproduced with direct grim call: `grim -o eDP-1 /tmp/test.png` → `supplied geometry did not intersect with any outputs`. Confirmed it's not a slurp problem.
5. Verified `wayshot -o eDP-1 ...` works (writes valid PNG), proving the screencopy protocol itself is fine — the bug is grim-specific.
6. Noted `system/users/jorge/programs/default.nix:163-164` already installs `grimblast` and `wayshot` with comments calling out exactly this fractional-scaling issue, but the keybind was never updated to use them.
7. Ran `grimblast check` — all required tools (grim, slurp, hyprctl, hyprpicker, wl-copy, jq, notify-send) present.
**Fix:** Replaced the bind in `dotfiles/hypr/shared/workflow/default/binds/qwerty.conf:15` with `bind = $mainMod, v, exec, grimblast copy area`. Reloaded with `./hypr.sh`. The same broken pattern still exists in `dvp.conf:19`, `dvp.conf:22`, `voyager1H.conf:11`, `voyager2H.conf:21`, and `voyager2H-old.conf:11` for other users — left untouched per scope.
**Commit:** `<pending>`
