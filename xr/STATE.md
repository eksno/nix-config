# XR system state

Last updated: 2026-05-05

What is currently deployed on `lewis`, what is verified working, and what
is broken or deferred. Update this whenever the deployed state changes
(new module wired in, new contract changed, new known-broken thing).

## Hosts in scope

| Host | User | Status |
|---|---|---|
| `lewis` | `jorge` | xr-driver + breezy packages deployed; sideview wrapper installed but blocked by nested-shell architectural wall (see LEARNINGS.md "nested gnome-shell on Hyprland is impossible") |
| `verse` | `eksno` | Not yet wired. Same hardware contract expected once lewis has a working path. |

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
  - With glasses + correct config: `/dev/shm/breezy_desktop_imu` exists,
    byte 0 = `05` (DATA_LAYOUT_VERSION)
  - `/dev/shm/xr_driver_state` shows `connected_device_brand=RayNeo`,
    `calibration_state=CALIBRATED`, etc.

### `breezy-gnome` (working as a build artifact only)

- **Package**: `system/lib/xr/breezy-gnome/{package.nix,default.nix}`. Builds
  upstream `wheaney/breezy-desktop` v2.9.12 with `fetchSubmodules = true`
  (required — `gnome/src/Sombrero.frag` and textures symlink into
  `modules/sombrero/`).
- **Output**: `share/gnome-shell/extensions/breezydesktop@xronlinux.com/`
  with all `*.js`, `*.frag`, `dbus-interfaces/`, `textures/`, and a
  compiled `schemas/gschemas.compiled`.
- **Deployment**: in `environment.systemPackages`, lands at
  `/run/current-system/sw/share/...` (per-user XDG_DATA_DIRS picks it up
  *if* anything actually loads gnome-shell, which currently nothing does).
- **Status**: builds clean; not actively consumed because the wrapper
  intended to consume it can't run (see below).

### `breezy-sideview` wrapper (blocked)

- **Package**: `system/lib/xr/breezy-sideview/{package.nix,default.nix}`.
  Bash wrapper via `writeShellApplication`, plus a NixOS module setting
  `services.logind.settings.Login.HandleLidSwitchExternalPower = "ignore"`.
- **`gnome-shell` source**: pinned to a separate flake input
  `nixpkgs-gnome48` (currently `github:nixos/nixpkgs/nixos-25.05`, GNOME
  48.2). v49 removed `--nested`; v48 still has it. Flake input was added
  for this single package.
- **Status**: **blocked**. Even on v48, `gnome-shell --nested --wayland`
  under Hyprland fails Clutter init because mutter's `--nested` is
  actually nested-on-X11 and goes through XWayland; Clutter then can't
  pick a working GL backend. See LEARNINGS.md for the full trace.

### Hyprland integration (loaded; bound to a non-functional binary)

- **Keybinds**: `dotfiles/default/hypr/users/jorge/default/breezy.conf`
  - Super+T: `breezy-sideview --toggle --preset 2-screen`
  - Super+Shift+T: `breezy-sideview --toggle --preset 3-screen` (3-screen
    is a stub that warns and falls back; upstream gschema lacks a
    virtual-display-count key)
  - Super+R: `breezy-recenter.sh` — writes `recenter_screen=true` to
    `/dev/shm/xr_driver_control`
- **Windowrules**: block-form (the v0.54 syntax — see LEARNINGS.md). Match
  on `gnome-shell` class and `GNOME Shell` title; act `float = true`,
  `fullscreen = true`, `monitor = desc:Technical Concepts Ltd SmartGlasses`.
- **Disconnect watcher**: `breezy-monitor-watcher.sh` listens on Hyprland's
  socket2; reaps sideview if the glasses output disappears.
- **Status**: keybinds verified loaded via `hyprctl binds | grep -i breezy`.
  The `exec` targets resolve, but the wrapper itself is non-functional.

### Update flow improvements (working)

- `update.sh` now appends `hyprctl reload` after a successful rebuild on
  Hyprland hosts (gated on `HYPRLAND_INSTANCE_SIGNATURE`).
- New `update-without-update.sh`: same as `update.sh` but skips both
  `nix flake update` calls. Use this for "rebuild against existing
  flake.lock" — avoids multi-GiB redownloads on each iteration.

## What's broken / deferred

| Thing | Reason | Where to look next |
|---|---|---|
| Sideview end-to-end | Nested gnome-shell can't work on Hyprland (architectural — see LEARNINGS.md) | New plan — see PLAN.md |
| 3-screen preset | Upstream gschema has no virtual-display-count key | Upstream feature request, or set monitor count via `MUTTER_DEBUG_DUMMY_MODE_SPECS` if we ever get nested running |
| `wifite2` | Commented out in jorge + eksno program lists; nixpkgs-unstable wireshark hash mismatch | Re-enable when upstream fixes wireshark-cli source hash |

## Memory pointers

- `~/.claude/projects/-home-jorge-nix-config/memory/feedback_hyprctl_reload.md`:
  always chain `&& hyprctl reload` after rebuilds on Hyprland hosts (now
  baked into update scripts; the rule still applies for ad-hoc rebuilds)
- `~/.claude/projects/-home-jorge-nix-config/memory/user_glasses.md`: model
  identification (Rayneo Air 3s Pro / 4 Pro confusion noted)
