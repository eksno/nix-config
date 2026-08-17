---
type: project
title: Monado service + launcher IPC quirks
created: 2026-05-06
---

`monado-service` and the `breezy-hyprland` launcher have non-obvious
runtime requirements. All three were discovered the hard way; documenting
so future changes to the launcher don't regress them.

## monado-service stdin must be a pollable fd

monado-service polls its stdin to detect parent shutdown. If stdin is
a TTY or `/dev/null`, the polling loop misbehaves. The launcher feeds
it from a pipe.

## The pipe must stay open

Common wrong pattern: `true | monado-service ...`. The `true` exits
immediately, closing the write end, which monado interprets as parent
death and exits. **Correct pattern**: `sleep infinity | monado-service ...`
(or any long-lived process holding the write end).

## XR_RUNTIME_JSON must be set in the launcher's own env

We override the OpenXR runtime to point at our `monado-rayneo`. Setting
`XR_RUNTIME_JSON` system-wide via `environment.sessionVariables` only
takes effect on the **next login**. The launcher must also export it in
its own process so wayvr (running as a child) sees it on first run after
deployment. Both are set; don't remove either.

## Cleanup discipline

The launcher's cleanup trap MUST use SIGINT (`kill -INT`) and wait for
monado to exit gracefully. Never SIGKILL. See
[Don't SIGKILL DRM-grabbing processes](xr-shutdown-discipline.md) for
why — short version: monado releases the DRM lease in its shutdown
handler, and a SIGKILL leaves Hyprland's monitor list in a corrupt state
that requires `hyprctl reload` (often two or three times) to recover.

The current cleanup trap also restores the glasses monitor via
`hyprctl keyword monitor "$GLASSES_BASELINE"` as a safety net. With the
EDID override active the monitor never appears in Hyprland's view, so
this is a no-op in the normal case — kept for the rollback path.

## Logs

monado-service writes to `/run/user/$(id -u)/monado-service.log`. Always
tail this when debugging the lease handoff or Vulkan surface creation.
The launcher itself doesn't write a separate log — its stderr goes to
wherever Hyprland forwards launcher stderr (journalctl --user-unit
hyprland or similar).
