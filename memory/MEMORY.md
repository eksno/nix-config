# Memory index

<!-- One line per topic file under each heading. Format:
     - [Title](file.md) — one-line hook -->

## user

(none yet — global ~/.claude/.../memory has user-level facts)

## project

### xr/ subsystem

- [XR stack overview](xr-stack-overview.md) — entry point: packages, modules, data flow, what does what
- [Mesa anv direct-mode SURFACE_LOST](xr-mesa-anv-display-gap.md) — surface+swapchain create succeed, first present fails. Misdiagnosed earlier as "missing VK_KHR_display device funcs" — that was wrong. Check before suggesting fixes.
- [wlroots leasing rules](xr-wlroots-leasing-rules.md) — only EDID-non-desktop connectors get advertised via wp-drm-lease-v1. `hyprctl monitor disable` does NOT make a connector leasable.
- [Rayneo hardware facts](xr-rayneo-hardware.md) — Air 4 Pro 1bbb:af50, DP-2 on lewis, cable-quality gotcha, USB ACL boot-race fix
- [EDID override module](xr-edid-override.md) — how `glasses-edid/` flips non_desktop=1, how to regenerate the patched blob, per-host caveats
- [Monado/launcher IPC quirks](xr-monado-ipc-quirks.md) — pollable stdin, persistent pipe, XR_RUNTIME_JSON propagation. Ignore at your peril.
- [Offline OSS source corpus](xr-research-corpus.md) — `.research/` (~1.8 GB, gitignored): mesa, monado, kernel DRM, Hyprland, wlroots, etc. Grep here before re-fetching.
- [Mesa wsi_display tracing is disabled](xr-mesa-wsi-debug-disabled.md) — `MESA_VK_WSI_DEBUG=display` is a no-op; the macro is `#if 0`'d at `wsi_common_display.c:99-105`.
- [Mesa anv first-present atomic_commit returns EBUSY](xr-mesa-anv-ebusy-on-first-present.md) — kernel EBUSY on `DRM_IOCTL_MODE_ATOMIC`; Mesa flattens it to `VK_ERROR_SURFACE_LOST_KHR` at `wsi_common_display.c:3129`. Leading hypothesis: CRTC contention with Hyprland's stale aquamarine binding (unconfirmed).
- [wayvr capture segfault — `upload_image` memcpy](xr-wayvr-gpu-capture-segfault.md) — root cause located via coredump: `WCommandBuffer::upload_image` `copy_from_slice` from a raw mmap'd slice with no `MAP_FAILED` check. Independent of DMA-BUF vs CPU capture method.
- [Hyprland CDCLK budget cap on lewis](xr-hyprland-cdclk-cap.md) — wp_drm_lease_v1 + eDP-1@120 + HDMI-A-1@120 + DP-2@60 SBS exceeds Intel display engine budget → safe-mode loop. Cap one refresh rate.
- [Hyprland lease-hotplug event-loop stall](xr-hyprland-lease-hotplug-stall.md) — second class of safe-mode crash distinct from CDCLK; watchdog SIGABRTs during aquamarine `SDRMConnector::connect` on DP-2 hot-plug while monado is leasing. Check log at crash time, not session start.
- [Rayneo glasses are libusb, not hidraw](xr-rayneo-libusb-not-hidraw.md) — `1bbb:af50` opens via `/dev/bus/usb/...` with `USBDEVFS_DISCONNECT_CLAIM`. lewis hidraws are Intel ISH + touchpad. Don't conflate.
- [monado-rayneo uses its own RAYNEO_LOG env var (default WARN)](xr-monado-debug-log-level.md) — XRT_LOG=debug alone is NOT enough. Rayneo driver has `DEBUG_GET_ONCE_LOG_OPTION(RAYNEO_LOG, WARN)`; need `RAYNEO_LOG=debug` to see SwitchTo3D path.
- [xr-driver vs monado-rayneo USB conflict](xr-usb-driver-coordination.md) — `systemctl --user stop xr-driver` races; auto-restart re-claims USB. Use `mask` for clean monado runs, `unmask` after.
- [SIGKILL on monado strands the USB claim](xr-monado-sigkill-usb-stuck.md) — kernel keeps `USBDEVFS_DISCONNECT_CLAIM` for the dead PID; soft-reset via `/sys/bus/usb/drivers/usb/{unbind,bind}` recovers without replug.
- [Rayneo replug can come back USB-only (no DP altmode)](xr-rayneo-dp-altmode-replug.md) — DP altmode is direction-sensitive; sometimes need to flip the USB-C cable orientation. Detect via `/sys/class/typec/port1-partner/accessory_mode=none` or DP-2 stuck `disconnected`.
- [Rayneo connector name varies (DP-1 vs DP-2)](xr-rayneo-connector-name-varies.md) — the glasses are NOT always on DP-2. Probe by description or by enumerating all card1-DP-*/edid sizes. EDID firmware override keyed on DP-2 may not apply on DP-1.
- [ASUS UCSI gets stuck on lewis](xr-asus-ucsi-stuck.md) — `ucsi_acpi USBC000:00: GET_CONNECTOR_STATUS failed (-70)` makes USB-C plug events stop reaching userspace. Driver rebind doesn't fix it. `systemctl suspend` + wake does. Don't wiggle cable — suspend. (Note: a deeper variant exists where suspend doesn't fix it either; see next entry.)
- [lewis altmode discovery state machine stuck](xr-lewis-altmode-discovery-stuck.md) — UCSI sees plug + PD2 OK but never registers altmodes. **Soft reboot does NOT fix it; cold power cycle (30s power button hold) does.** Don't blame cable if it works on phone. UCSI trace recipe inside.
- [lewis EC refuses CAM registration entirely (deeper failure)](xr-lewis-ec-refuses-altmode.md) — even after cold cycle, EC's `GET_CAM_SUPPORTED` returns 0 and `SET_NEW_CAM` times out, despite partner advertising SVID 0xff01. **5-command UCSI debugfs recipe inside fingerprints this in 30 seconds.** Likely needs BIOS update (UX3405MA.301 is 2.5y stale) or a TBT4-certified cable. xr-driver/IMU still works over plain USB.
- [v2 runner truncate makes monado log sparse](xr-v2-runner-sparse-log.md) — orphan monado fd at high offset causes NUL-padded sparse file → ripgrep "binary file matches". Verify `pgrep monado-service` empty first.
- [wayvr logs are UTC, system is UTC+7](xr-wayvr-utc-timestamps.md) — a `2026-05-06T19:13Z` wayvr line is `2026-05-07T02:13` local; not stale, just a different timezone label.

### nixos build + host model

- [NixOS rebuild flow](nixos-rebuild-flow.md) — `update.sh` quirks (`git add .` before flake), `--impure`, dotfile activation script, fast-iteration without flake bumps
- [Host context detection protocol](nixos-host-context-protocol.md) — `fastfetch` first (mandatory), then host/user → directory mapping
- [lewis host profile](lewis-host-profile.md) — Intel Arc, Hyprland primary, battery cap 85%, primary dev box

### upstream constraints

- [Breezy productivity-tier paywall](breezy-license-paywall.md) — why `breezy-gnome` was abandoned; what stays installed as fallback

## feedback

- [Verify before recommending from memory](process-verify-before-recommend.md) — memory says "X existed when written," not "X exists now." Grep/read first.
- [Don't SIGKILL DRM-grabbing processes](xr-shutdown-discipline.md) — SIGINT + wait, never SIGKILL. Killing mid-frame trashes Hyprland's monitor list.

## reference

- [XR debug commands](xr-debug-commands.md) — drm_info paths, vulkaninfo greps, edid-decode, monado log location, hyprctl probes
- [xr-driver control IPC](xr-driver-control-ipc.md) — `/dev/shm/xr_driver_control` keys (sbs_mode=enable/disable, recenter_screen=true), state file, validation gotchas
