# XR system state

Last updated: 2026-05-06

What is currently deployed on `lewis` (and wired for `verse`), what is
verified working, and what is broken or deferred. Update this whenever
the deployed state changes (new module wired in, new contract changed,
new known-broken thing).

## Hosts in scope

| Host | User | Status |
|---|---|---|
| `lewis` | `jorge` | xr-driver + breezy-gnome + breezy-session + breezy-recenter + **monado-rayneo + breezy-hyprland** deployed. GNOME-Breezy soak abandoned (productivity-tier paywall). Active path is `plans/03-hyprland-breezy-2026-05-06.md` — Phases 1+2 shipped (monado patched, launcher orchestrates monado+wayvr to OpenXR FOCUSED), Phase 3 replanned 2026-05-06 around EDID non-desktop override (the original `hyprctl keyword monitor disable` approach was proven wrong by direct test — wlroots only leases EDID-non-desktop outputs). |
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
- **Verified**: `monado-cli probe` shows
  `head: RayNeo Air 4 Pro (5e0050125135323833390000), view count: 2`
  after stopping xr-driver to release HID locks.

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
