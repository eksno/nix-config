---
type: project
title: Rayneo glasses connector name on lewis varies — sometimes DP-1, sometimes DP-2
created: 2026-05-07
---

The Rayneo Air 4 Pro on `lewis` does NOT consistently come up as DP-2.
It varies between **DP-1** and **DP-2** across sessions, hot-plugs,
cable swaps, and PCIe re-enumeration.

Empirical:

- Earlier sessions: DP-2 (our entire debugging vocabulary assumed this)
- 2026-05-07 14:12 hot-plug: came up as DP-1 (kernel `drm: connector
  DP-1 connected ... SmartGlasses 0x00000011 (DP-1)`, log line 79842
  in active Hyprland session)
- DP-2 sometimes stays `disconnected` while DP-1 is the live one, and
  vice versa

## Why this matters

1. ~~The EDID firmware override at `system/lib/xr/glasses-edid/default.nix`
   is keyed on DP-2 only.~~ **FIXED 2026-05-08 (`96dd306`)**: the
   override now lists both DP-1 and DP-2, so wp-drm-lease-v1
   advertises the glasses regardless of which connector they land on.
   The kernel only applies the override on the matching connector,
   so listing both is safe.
2. All sysfs probes (`/sys/class/drm/card1-DP-2/status` etc.) return
   misleading `disconnected` on the wrong connector, masking a working
   DP-1.
3. Hyprland identifies the monitor by description (`Technical Concepts
   Ltd SmartGlasses`), not by connector name, so its `monitor` keyword
   keeps working regardless of name. Scripts that hardcode `DP-2`
   break.

## How to detect which connector landed

Don't probe DP-2 by name. Probe ALL DP connectors and find the one
with a non-zero EDID:

```bash
for f in /sys/class/drm/card1-DP-*/status; do
  c=${f%/status}
  s=$(cat "$f")
  e=$(stat -c%s "$c/edid" 2>/dev/null || echo 0)
  echo "$(basename "$c"): status=$s edid=${e}B"
done
```

Or grep the live Hyprland log for the most recent `SmartGlasses` line
to learn which connector aquamarine bound:

```bash
rg -n 'SmartGlasses' /run/user/1000/hypr/*/hyprland.log | tail -5
```

## How to apply

- Always probe by description, not connector name.
- Audit `system/lib/xr/glasses-edid/default.nix` — the EDID override
  may need a wider match or to be applied on hot-plug.
- Do NOT trust `/sys/class/drm/card1-DP-2/status=disconnected` as
  evidence the glasses are missing — check DP-1 too (and any other
  card1 DP connector).

## Companion gotcha

Hyprland's `0x0@60.00000 at 2304x0` mode in `hyprctl monitors` is NOT
a stale ghost — it's the placeholder geometry shown when the
connector has been leased out via `wp-drm-lease-v1`. Do not
`hyprctl reload` to "flush" it; that yanks the lease from monado.
