# XR system state

Last updated: 2026-05-06

What is currently deployed on `lewis` (and wired for `verse`), what is
verified working, and what is broken or deferred. Update this whenever
the deployed state changes (new module wired in, new contract changed,
new known-broken thing).

## Hosts in scope

| Host | User | Status |
|---|---|---|
| `lewis` | `jorge` | xr-driver + breezy-gnome + breezy-session + breezy-recenter + **monado-rayneo (patched: comp-renderer pairs COLOR_ATTACHMENT_BIT with STORAGE_BIT, VERIFIED) + breezy-hyprland (with wayvr-anv override) + glasses-edid (EDID override + 3840x1080 mode injection + USB ACL fix)** deployed. GNOME-Breezy soak abandoned. **Phase 3 progress:** (1) launcher socket race FIXED commit `f74154b`; (2) EDID injects 3840x1080@60 DTD so monado renders SBS at native (commit `7122089`); (3) **monado swapchain usage-flag patch (`3bf13da`) VERIFIED on the monado side** — latest v3 run shows clean swapchain present cycle, no SURFACE_LOST, frames presenting at ~30 fps with "missed frame by 16ms" warnings, both wayvr OpenXR clients connect and disconnect normally. User-facing "see something on the glasses" outcome remains gated on the wayvr crash (next bullet). **Open issues:** (a) **wayvr capture-init crash on Mesa anv:** every diagnostic run segfaults wayvr right after the "Using GPU capture" warning at `wayvr/src/overlays/screen/backend.rs:200`. The atlas-grow workaround patch (`b02dffa`, wayvr-anv override) was confirmed to suppress the `Grow Color atlas` log line but did NOT prevent the segfault. **Round 2 (2026-05-06):** CPU-capture override at `~/.config/wayvr/config.yaml` (out-of-tree — see TODO below) IS picked up (log shows `Not using DMA-buf capture due to ScreenCopyCpu`) but wayvr still segfaults one log line later, after `Software capture will take place on the main thread`. So both the atlas log AND the DMA-BUF import were coincident, not causal — the actual crash is in the post-method-decision capture-init region (possibly Vulkan queue setup or vulkano-anv interaction). Need a backtrace via gdb / coredump; "blame the last log line" has misfired twice. See `memory/xr-wayvr-gpu-capture-segfault.md`. (b) **Hyprland safe-mode root cause now identified, fix landed but regression still open:** root cause was Intel CDCLK budget overrun when wp_drm_lease_v1 added DP-2@3840x1080@60 on top of eDP-1@120 + HDMI-A-1@120 (~1.12 GP/s, exceeds the ~1.0 GP/s ceiling). Aquamarine logged `drm: Cannot commit when a page-flip is awaiting` repeatedly; watchdog killed Hyprland into safe-mode. Smoking gun in `/run/user/1000/hypr/521ece...1778064687_*/hyprland.log` lines 511-513. Workaround landed in commit `1f84b02` capping HDMI-A-1 to 60Hz (total ~995 MP/s, under threshold). **STILL OPEN:** even after `1f84b02`, Hyprland continues to end up in safe-mode on plain login (root cause unknown; possibilities include leftover state from prior crashes, an EDID/mode-string mismatch on HDMI-A-1, or another CDCLK pathology). See `memory/xr-hyprland-cdclk-cap.md`. (c) **TODO — codify the wayvr CPU-capture workaround into dotfiles:** `~/.config/wayvr/config.yaml` is currently out-of-tree (dropped directly for fast iteration, confirmed picked up but did NOT fix the segfault). Once a real fix exists, move the desired config (and the `capture_method: screencopy` setting if it stays) into `dotfiles/default/wayvr/config.yaml` so the dotfile-symlink activation script deploys it. (d) **Minor:** stale `/run/user/1000/monado_comp_ipc` socket can persist after an unclean monado exit; the launcher's `f74154b` cleanup only runs on launcher startup, not on un-clean exit. Next launch handles it; not urgent. |
| `verse` | `eksno` | Same module set wired (xr/driver, xr/breezy-gnome, xr/breezy-session, xr/monado-rayneo, xr/breezy-hyprland). Build verified; not yet exercised on real hardware. |

## What's deployed

### `xr-driver` (working)

- **Package**: `system/lib/xr/driver/{package.nix,default.nix}`. XRLinuxDriver
  v2.9.4. Includes patched udev rules (Rayneo hidraw subsystem match,
  uinput uaccess) and a stubbed `imu_protocol_xreal_one` so we can drop the
  XREAL One Rust subdriver without breaking link.
- **Runtime config**: `dotfiles/default/xr_driver/config.ini`. Three lines:
  ```
  disabled=false
  output_mode=external_only
  external_mode=breezy_desktop
  use_roll_axis=true
  ```
  `external_mode=breezy_desktop` is what enables the SHM IPC writer;
  `output_mode=external_only` alone is not enough.
- **Deployment**: Repo template installed by systemd `ExecStartPre install
  -Dm644 ${...}/dotfiles/default/xr_driver/config.ini %h/.config/xr_driver/config.ini`.
  The driver mutates this file at runtime (e.g. flips `disabled=true` when
  no headset is connected), so the install-on-restart pattern keeps the
  repo deterministic.
- **Verified contracts**:
  - `systemctl --user is-active xr-driver` → active
  - Glasses connected: `udevadm info /dev/hidraw2` shows the device, mode
    `crw-rw----+` (uaccess) for the seat-active user
  - `/dev/shm/xr_driver_state` shows `connected_device_brand=RayNeo`,
    `calibration_state=CALIBRATED`, etc.
  - **`/dev/shm/breezy_desktop_imu` requires a productivity-tier
    license** — see "Productivity-tier license gate" below. Without it,
    the breezy_desktop plugin's SHM writer never initializes and the
    file is never created, regardless of `external_mode=breezy_desktop`.

### `breezy-gnome` (working as a build artifact + consumed by GNOME-on-Wayland session)

- **Package**: `system/lib/xr/breezy-gnome/{package.nix,default.nix}`. Builds
  upstream `wheaney/breezy-desktop` v2.9.12 with `fetchSubmodules = true`
  (required — `gnome/src/Sombrero.frag` and textures symlink into
  `modules/sombrero/`).
- **Output**: `share/gnome-shell/extensions/breezydesktop@xronlinux.com/`
  with all `*.js`, `*.frag`, `dbus-interfaces/`, `textures/`, and a
  compiled `schemas/gschemas.compiled`.
- **Deployment**: in `environment.systemPackages`. Picked up by the
  GNOME-on-Wayland session via standard XDG_DATA_DIRS extension lookup,
  then activated by the dconf seed (see `breezy-session` below).

### `breezy-session` (working — registers GNOME-on-Wayland with SDDM, seeds dconf)

- **Module**: `system/lib/xr/breezy-session/default.nix`.
  - `services.desktopManager.gnome.enable = true;` puts
    `gnome-session-49.2-sessions` into `services.displayManager.sessionPackages`,
    which surfaces `gnome.desktop` and `gnome-wayland.desktop` in SDDM's
    SessionDir.
  - `services.displayManager.gdm.enable = lib.mkForce false;` —
    `desktopManager.gnome.enable` flips GDM on transitively; the override
    keeps SDDM as the DM for both Hyprland and GNOME.
  - `services.logind.settings.Login.HandleLidSwitchExternalPower = "ignore";`
    — migrated from the deleted `breezy-sideview` module.
  - `programs.dconf.profiles.user.databases` seeds:
    - `org/gnome/shell enabled-extensions = ['breezydesktop@xronlinux.com']`
    - `com/xronlinux/BreezyDesktop` preset: `display-distance=1.05`,
      `display-size=1.0`, `curved-display=false`, `widescreen-mode=false`
    - `org/gnome/settings-daemon/plugins/media-keys` Super+R custom-keybinding
      pointing at `breezy-recenter`
- **Imports `breezy-recenter`** so the GNOME custom-keybinding's command
  resolves on `$PATH` regardless of import order.

### `breezy-recenter` CLI (working — bound from both compositors)

- **Package**: `system/lib/xr/breezy-recenter/{package.nix,default.nix}`.
  `writeShellApplication` that writes `recenter_screen=true` to
  `/dev/shm/xr_driver_control`.
- **Bound**:
  - Hyprland: `Super+R` via
    `dotfiles/default/hypr/users/jorge/default/breezy.conf`.
  - GNOME-on-Wayland: `Super+R` via the dconf custom-keybinding seeded by
    `breezy-session`.
- Replaces the deleted `dotfiles/default/hypr/shared/scripts/breezy-recenter.sh`.

### Hyprland integration (loaded; still relevant for recenter + monitor watcher)

- **Keybinds**: `dotfiles/default/hypr/users/jorge/default/breezy.conf`
  - Super+R: `breezy-recenter` (the new CLI)
- **Disconnect watcher**: `breezy-monitor-watcher.sh` listens on Hyprland's
  socket2; reaps any sideview helpers if the glasses output disappears.
  Kept for now — cheap, harmless if it never fires; revisit in soak if
  it surfaces a reason to drop.

### `monado-rayneo` (working — patched OpenXR runtime)

- **Package**: `system/lib/xr/monado-rayneo/{package.nix,default.nix}`.
  Overrides nixpkgs `monado` with the head SHA of MR !2737
  (gitlab.freedesktop.org/monado/monado/-/merge_requests/2737), which
  adds a dedicated `rayneo` driver for USB `1bbb:af50`. Stock Monado's
  `xreal_air` builder only matches XREAL VID 0x3318 and does NOT
  enumerate the Rayneo.
- **Patch filter**: drops nixpkgs' `monado-cylinder-aspectRatio.patch`
  (the MR is post-25.1 and already includes the upstream commit it
  backports — applying it again fails with
  "Reversed (or previously applied)").
- **In-tree patch (monado-side VERIFIED 2026-05-06)**:
  `system/lib/xr/monado-rayneo/patches/comp-renderer-scanout-compatible-tiling.patch`
  pairs `VK_IMAGE_USAGE_COLOR_ATTACHMENT_BIT` with `STORAGE_BIT` in
  `comp_renderer.c:543-549` so Mesa anv selects a scanout-compatible
  tiling for the compute-path swapchain. Latest v3 run shows clean
  swapchain present cycle (no SURFACE_LOST), frames presenting at
  ~30 fps with frame-miss warnings, both OpenXR clients connecting +
  disconnecting normally. Qualifier: monado-side fix verified; the
  user-facing "see something on the glasses" outcome is gated on
  the wayvr GPU-capture segfault — see
  `memory/xr-wayvr-gpu-capture-segfault.md`. Companion writeup:
  `memory/xr-mesa-anv-display-gap.md`.
- **Verified**: `monado-cli probe` shows
  `head: RayNeo Air 4 Pro (5e0050125135323833390000), view count: 2`
  after stopping xr-driver to release HID locks.

### `glasses-edid` (deployed; verified post-reboot 2026-05-06)

- **Module**: `system/lib/xr/glasses-edid/default.nix`. Two host-level
  fixes:
  1. **EDID non-desktop override** via `hardware.firmware` +
     `boot.kernelParams = [ "drm.edid_firmware=DP-2:edid/rayneo-air4pro-glasses.bin" ]`.
     Patched EDID inserts a Microsoft HMD VSDB into the CTA-861
     extension; kernel parses it and sets
     `connector.non_desktop = true`.
  2. **USB ACL fix** via `services.udev.extraRules` setting
     `MODE="0660", GROUP="users"` for vendor 1bbb / product af50.
     Works around the upstream `uaccess`-tag rule's boot-time
     race (logind not yet running when device enumerates → ACL
     never applied → user gets EACCES on `open()` until they
     hot-plug). See LEARNINGS.md "USB device ACL boot-race".
- **Source artifacts** in `xr/edid/`:
  - `glasses-original.bin` — captured from `/sys/class/drm/card1-DP-2/edid`
  - `patch_glasses_edid.py` — inserts the Microsoft HMD VSDB,
    bumps DTD start offset, recomputes the CTA-861 checksum
  - `glasses-nondesktop.bin` — patched output, verified with
    `edid-decode` (Microsoft VSDB recognized; DTDs preserved;
    checksum valid)
- **Verified live** (2026-05-06 after reboot):
  - `nix run nixpkgs#drm_info` → DP-2 "non-desktop" property = 1
  - `hyprctl monitors` → DP-2 absent (success); `monitors all` lists
    it with `0x0@60` (no active mode) — correct for non-desktop
  - monado log → `_lease_connector_done [/dev/dri/card1] connector
    DP-2 (Technical Concepts Ltd SmartGlasses 0x00000011 (DP-2))
    id: 528` — lease accepted via wp-drm-lease-v1
  - rayneo USB driver opens device after USB ACL fix is live (and
    before via replug); head pose flowing, IPD = 63mm

### `breezy-hyprland` (working through OpenXR FOCUSED — visual rendering needs Phase 3)

- **Module**: `system/lib/xr/breezy-hyprland/default.nix`.
  Adds `pkgs.wayvr` (26.2.1, the renamed WlxOverlay-S) and the
  launcher to systemPackages. Sets `environment.variables.XR_RUNTIME_JSON`
  pointing at the patched monado's `share/openxr/1/openxr_monado.json`.
- **Launcher**: `system/lib/xr/breezy-hyprland/launcher.nix`.
  `writeShellApplication` named `breezy-hyprland`. Stops xr-driver to
  release HID locks, clears stale `monado.pid`, starts monado-service
  in background with `sleep infinity |` keeping its stdin pipe alive
  (see LEARNINGS.md for the full epoll-on-stdin / pipe-EOF / env-var
  story), waits for the OpenXR socket, then `exec wayvr --openxr --show`.
  EXIT trap kills monado, reaps the sleep, restarts xr-driver.
- **Verified through OpenXR FOCUSED**: WayVR connects to Monado, finds
  the Rayneo as the head device, walks IDLE → READY → SYNCHRONIZED →
  VISIBLE → FOCUSED with IPD = 63mm, GPU screen capture inits, UI text
  atlas drawn.
- **NOT yet correct visually**: Monado falls back to Wayland-windowed
  mode (`Found no connectors available for direct mode`) because
  wlroots/Hyprland only advertises EDID-non-desktop outputs via
  `wp-drm-lease-v1`, and the Rayneo glasses identify as a regular
  monitor. The 3840x1080 SBS Wayland surface lands wrongly; user sees
  half-rendered + rainbow bars; Hyprland watchdog flags it
  ("Application Not Responding" popup). **Phase 3 fix** (replanned
  2026-05-06 in `plans/03-...`): EDID override via
  `boot.kernelParams = [ "drm.edid_firmware=DP-2:edid/glasses.bin" ]`
  to force the non-desktop bit, so wlroots auto-exposes the connector
  for lease and monado picks it up. (The original
  `hyprctl keyword monitor disable` plan was tested and proven worse
  than no toggle at all — see LEARNINGS.md.)
- **Launcher hygiene improvements (2026-05-06)**: cleanup trap now
  uses SIGINT (not default SIGTERM) on monado and waits up to 10s
  for graceful exit; `wayvr` no longer launched with `exec` (which
  killed the trap); cleanup trap restores the SmartGlasses monitor
  to its baseline mirror config as a safety net.

### Update flow improvements (working)

- `update.sh` now appends `hyprctl reload` after a successful rebuild on
  Hyprland hosts (gated on `HYPRLAND_INSTANCE_SIGNATURE`).
- `update-without-update.sh`: same as `update.sh` but skips both
  `nix flake update` calls. Use this for "rebuild against existing
  flake.lock" — avoids multi-GiB redownloads on each iteration.

## What's broken / deferred

| Thing | Reason | Where to look next |
|---|---|---|
| World-locked surfaces in the GNOME-Breezy session | Upstream productivity-tier license required (see below). Driver runs and connects, extension loads — but the SHM pose stream is gated. | Open-source path is now `breezy-hyprland` via Monado+WayVR (see `plans/03-...`); GNOME-Breezy stays as a fallback if anyone ever buys a tier. |
| Visual rendering on the glasses via `breezy-hyprland` | Monado in Wayland-windowed mode because wlroots only advertises EDID-non-desktop outputs for DRM lease, and the Rayneo glasses identify as a regular monitor. SBS-packed surface lands wrongly. | Phase 3 of `plans/03-hyprland-breezy-2026-05-06.md` — kernel-cmdline EDID override to flip the non-desktop bit, so wlroots auto-exposes the connector for lease. |
| Hot-switch between Hyprland and GNOME-Breezy without logout | No clean way without major re-architecture | Defer indefinitely; the open-source Hyprland path makes the GNOME session less critical. |
| 3-screen preset (GNOME-Breezy only) | Upstream gschema has no virtual-display-count key | Upstream feature request, or tolerate 2-screen. Not relevant to the new Monado+WayVR path. |
| `wifite2` | Commented out in jorge + eksno program lists; nixpkgs-unstable wireshark hash mismatch | Re-enable when upstream fixes wireshark-cli source hash |

### Productivity-tier license gate

The breezy_desktop plugin in `XRLinuxDriver` v2.9.4
(`src/plugins/breezy_desktop.c`) gates its SHM-writer initialization on:

```c
temp_config->enabled = list_string_contains("breezy_desktop", value)
                    && is_productivity_granted();
```

`is_productivity_granted()` returns true only if `granted_features` from
the device license JSON contains either `"productivity"` or
`"productivity_pro"`. The license is stored at
`~/.local/state/xr_driver/<8-char-hwid-prefix>_license.json` and is
**signed** with `license_public_key.pem` baked into the driver binary —
not bypassable by editing the JSON.

When the license has `"tiers":{}` (free tier), the SHM file
`/dev/shm/breezy_desktop_imu` is never created, the GNOME extension has
nothing to read, no top-bar icon appears, and there is no world-lock —
even though the driver itself runs cleanly, connects to the glasses,
and produces `/dev/shm/xr_driver_state` correctly.

This is **not a bug in our packaging or session module** — it's an
upstream paywall. The architecture is correct end-to-end; only the
pose-stream payload is gated. Diagnose by:

```fish
cat ~/.local/state/xr_driver/*_license.json
# Look for: "tiers":{...}   ← non-empty means a tier is granted
# Or:        "tiers":{}      ← free tier; world-lock will not work
```

## Memory pointers

- `~/.claude/projects/-home-jorge-nix-config/memory/feedback_hyprctl_reload.md`:
  always chain `&& hyprctl reload` after rebuilds on Hyprland hosts (now
  baked into update scripts; the rule still applies for ad-hoc rebuilds)
- `~/.claude/projects/-home-jorge-nix-config/memory/user_glasses.md`: model
  identification (Rayneo Air 3s Pro / 4 Pro confusion noted)
- `~/.claude/projects/-home-jorge-nix-config/memory/reference_xr_workbench.md`:
  pointer back to `xr/` workbench
