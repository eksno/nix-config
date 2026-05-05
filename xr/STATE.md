# XR system state

Last updated: 2026-05-05

What is currently deployed on `lewis` (and wired for `verse`), what is
verified working, and what is broken or deferred. Update this whenever
the deployed state changes (new module wired in, new contract changed,
new known-broken thing).

## Hosts in scope

| Host | User | Status |
|---|---|---|
| `lewis` | `jorge` | xr-driver + breezy-gnome + breezy-session + breezy-recenter deployed. GNOME-on-Wayland session selectable from SDDM after Hyprland logout; breezy-gnome auto-enabled with 2-screen preset; world-lock soak in progress (Step 7 of `plans/02-gnome-breezy-session-2026-05-05.md`). |
| `verse` | `eksno` | Same module set wired (xr/driver, xr/breezy-gnome, xr/breezy-session). Build verified; not yet exercised on real hardware. |

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

### Update flow improvements (working)

- `update.sh` now appends `hyprctl reload` after a successful rebuild on
  Hyprland hosts (gated on `HYPRLAND_INSTANCE_SIGNATURE`).
- `update-without-update.sh`: same as `update.sh` but skips both
  `nix flake update` calls. Use this for "rebuild against existing
  flake.lock" — avoids multi-GiB redownloads on each iteration.

## What's broken / deferred

| Thing | Reason | Where to look next |
|---|---|---|
| World-locked surfaces in the GNOME-Breezy session | Upstream productivity-tier license required (see below). Driver runs and connects, extension loads — but the SHM pose stream is gated. | Either purchase a tier from https://breezy-desktop.com/ (license refreshes automatically, `tiers` field in `~/.local/state/xr_driver/<hwid>_license.json` populates), or fall back to `output_mode=mouse` (Path 4 — glasses-as-cursor). |
| Hot-switch between Hyprland and GNOME-Breezy without logout | No clean way without major re-architecture | Soak first. Revisit only if the logout boundary breaks UX badly enough. |
| 3-screen preset | Upstream gschema has no virtual-display-count key | Upstream feature request, or tolerate 2-screen. |
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
