---
type: feedback
title: Don't SIGKILL DRM-grabbing processes — SIGINT + wait
created: 2026-05-06
---

When killing monado, wayvr, or any process that has grabbed a DRM lease
or DRM master: send SIGINT (`kill -INT`), then wait up to ~10 seconds
for graceful exit. Only SIGKILL as an absolute last resort, and prefer
to investigate why graceful didn't work first.

## Why

These processes release their DRM resources in a SIGINT/SIGTERM
handler. Killing mid-frame leaves:

- Hyprland's internal monitor list in an inconsistent state (sometimes
  recoverable with `hyprctl reload`, sometimes requires logout/login)
- DRM lease still held by the kernel for the dead PID, blocking the
  next attempt to take the lease
- Wayland surfaces in zombie state if wayvr was a Wayland client

In practice on lewis, mid-frame SIGKILL of monado has trashed the
display once — required a Hyprland restart to recover.

## How to apply

In any cleanup script or trap:

```bash
kill -INT "$PID" 2>/dev/null || true
for _ in $(seq 1 100); do
  kill -0 "$PID" 2>/dev/null || break
  sleep 0.1
done
# only NOW, if still alive after ~10s:
kill "$PID" 2>/dev/null || true
```

The launcher at `system/lib/xr/breezy-hyprland/launcher.nix` follows
this pattern. Don't simplify it.

## Exception

If the EDID override is active *and* the process being killed never
had a successful Hyprland-managed monitor handoff (i.e. DP-2 was
non-desktop the whole time), the risk is lower because Hyprland never
considered the connector its own. Even so: SIGINT first.

## Source

- Saved as global memory previously after live incident
- Restated locally because it's central to xr/ work and any new launcher
  variant must respect it
