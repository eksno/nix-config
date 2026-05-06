---
type: reference
title: xr-driver control IPC — runtime mutation via /dev/shm/xr_driver_control
created: 2026-05-06
---

`xr-driver` (XRLinuxDriver v2.9.4) polls `/dev/shm/xr_driver_control`
for runtime config changes. Single-shot writes — daemon clears the
file after processing.

## Verified keys

```
recenter_screen=true                # one-shot pose recenter (also bound to Super+R)
sbs_mode=enable                     # glasses → 3D/SBS mode (XRMiniService::SwitchTo3D)
sbs_mode=disable                    # glasses → 2D mode      (XRMiniService::SwitchTo2D)
```

## Other keys present in the binary (not yet verified)

From `strings xrDriver | grep -E "^[a-z_]+$"` near the parser strings:

```
sbs_mode_stretched
auto_recenter_enabled
```

(`sbs_mode_stretched` may be a state flag rather than a control key —
needs source check or experimentation.)

## Validation behavior

The driver logs `Invalid sbs_mode value: %s` for any unrecognized
string. **Specifically rejected on test:** `true`, `false`, `0`, `1`,
`disabled`, `enabled`, `stretched`. The exact valid strings for
`sbs_mode` are `enable` / `disable` (singular, present-tense
imperative).

## Confirming a write took effect

Read `/dev/shm/xr_driver_state` (the daemon's published state file,
read-only for clients):

```
cat /dev/shm/xr_driver_state | grep -E "sbs_mode_enabled|connected_device"
# sbs_mode_enabled=true|false reflects the current SwitchTo2D/3D state
```

`~/.local/state/xr_driver/driver.log` has human-readable confirmations:

```
SBS mode has been enabled
SBS mode has been disabled
Invalid sbs_mode value: <bad>
Centering screen                    # after recenter_screen=true
```

## Relationship to xrlinuxdriver source

The control parser is in `src/state.c` (per breezy-recenter package
comment). The dispatch to libRayNeoXRMiniSDK is via plugin glue under
`src/plugins/`.

## Caveats

- xr-driver must be running. `breezy-hyprland` stops xr-driver to
  release HID locks for monado, so toggle BEFORE launching it.
- xr-driver does NOT toggle the glasses back to 2D when stopped; the
  glasses retain their last-set HID mode.
- License-gated functionality (productivity-tier paywall, see
  `breezy-license-paywall.md`) does not affect mode toggles — those
  work at the free tier.
