# Plan: World-locked AR sideview on Hyprland (sideview MVP)

## Context

Jorge runs Rayneo **Air 4 Pro** (USB `1bbb:af50`) on `lewis` (NixOS, Hyprland 0.54). The xr-linux-driver is already packaged at `system/users/jorge/dev/xr-driver/` and runs as a systemd user service in its default `output_mode=mouse` (head pose drives the system cursor). That's a stepping stone — the goal is **world-locked virtual screens** that float fixed in 3D space.

Upstream `breezy-desktop` has no wlroots/Hyprland support, so the production approach is to run a **nested `gnome-shell --nested --wayland`** inside a Hyprland window with the upstream `breezy-gnome` extension installed. The extension reads pose from `/dev/shm/breezy_desktop_imu` (the IPC contract); the driver, when configured with `output_mode=external_only`, writes pose to that same file. Both sides run as the same UID — no special permissions plumbing needed.

This plan stops at "sideview MVP works, Jorge daily-drives it for one week." A separate follow-up plan will cover the multi-config monitor layout-management system (auto-detect + presets + GUI). 3D/SBS stereoscopy is also deferred; Jonas's `verse` host gets the same modules so he can use sideview too.

## Verified facts (anchors that drive the design)

| Anchor | Source / verification |
|---|---|
| Driver writes pose to `/dev/shm/breezy_desktop_imu` when `output_mode=external_only` | XRLinuxDriver `src/config.c:14` (`external_only_output_mode`); `src/state.c:31` (`state_files_directory = "/dev/shm"`) |
| Extension reads from same file | breezy-desktop `gnome/src/devicedatastream.js:20` (`IPC_FILE_PATH = "/dev/shm/breezy_desktop_imu"`) |
| Extension UUID + supported shells | `gnome/src/metadata.json` → `breezydesktop@xronlinux.com`, `shell-version: ["46","47","48","49","50"]` |
| Extension lives at `gnome/src/` in the upstream repo (not `gnome/`) | curl confirmed |
| nixpkgs-unstable currently ships GNOME shell ≥47 (in supported range) | flake input is `nixos-unstable`; verify exact version when packaging |
| jorge's hypr config sources `~/.config/hypr/users/jorge/default/**.conf` | `dotfiles/default/hypr/users/jorge/default.conf:5` — any new `.conf` in that dir auto-loads |
| Dotfile pattern | per-app dirs in `dotfiles/default/<app>/`, linked into `~/.config/<app>` by `system/lib/dotfiles.nix` |
| `Super+B` is **taken** (waybar toggle, `dotfiles/.../jorge/default/startup.conf:5`) | grep — draft's `Super+B` for sideview would conflict |
| `Super+R` is **free** for jorge (binds to workspace 13 only on dvp/voyager layouts, not the active `qwerty.conf`) | grep |
| `Super+T` is **free** | grep — chosen as toggle key |
| gamescope is already enabled for jorge (`programs.gamescope.enable = true;`) | `system/users/jorge/programs/default.nix:33` — usable as a stable-window-class fallback |

## Key revisions from the draft

1. **`output_mode` value is `external_only`, not `external`** — verified against upstream `config.c`.
2. **`Super+B` conflicts with the waybar toggle**. New keybinds: `Super+T` (toggle sideview), `Super+Shift+T` (3-screen preset), `Super+R` (recenter).
3. **No source-vs-tarball comparison needed**. The release tarball bundles xrDriver binaries we already have; we just need the JS/schema files. Recommendation is source, period — copy `gnome/src/*` into `$out/share/gnome-shell/extensions/breezydesktop@xronlinux.com/` and `glib-compile-schemas` over `schemas/`.
4. **3D briefing isn't gating implementation** — drop it from MVP scope; if Jorge wants it later, it gets its own plan.
5. **Modules go in `system/lib/xr/`**, not `system/users/jorge/dev/`, so eksno can import them cleanly without cross-user paths. xr-driver also gets moved (one rename, low risk; the package definition is unchanged).
6. **xr-driver config goes through the existing dotfile pattern**, not custom activation logic. New file `dotfiles/default/xr_driver/config.ini`; new line in `system/lib/dotfiles.nix` to symlink it.

## Architecture

```
┌──────────────────────────────────────────────────────────────────────┐
│  Hyprland (host compositor on lewis, eDP-1 + glasses DP-2)           │
│                                                                       │
│   ┌─────────────────────┐         ┌──────────────────────────────┐   │
│   │ xr-driver (systemd  │ writes  │ /dev/shm/breezy_desktop_imu  │   │
│   │ user service)       │────────▶│ (binary pose, layout v5)     │   │
│   │ output_mode =       │         └──────────────────────────────┘   │
│   │   external_only     │                       │                     │
│   └─────────────────────┘                       │ reads               │
│         ▲                                       ▼                     │
│         │ Super+R                    ┌──────────────────────────┐    │
│         │ → xr_driver_cli            │ breezy-sideview wrapper  │    │
│         │   --recenter               │  ↓ exec                  │    │
│         │                            │ gnome-shell --nested     │    │
│         │                            │   --wayland (1 window)   │    │
│         │                            │   ├─ breezy-gnome ext    │    │
│         │                            │   └─ virtual surfaces    │    │
│         │                            └──────────────────────────┘    │
│         │  Super+T toggle, Super+Shift+T 3-screen                    │
│         └─ keybinds in dotfiles/.../jorge/default/breezy.conf        │
└──────────────────────────────────────────────────────────────────────┘
        ▲                                       ▲
        │                                       │
   Air 4 Pro                              Wear glasses, head turn:
   USB-C DP+HID                           virtual surfaces stay
                                          fixed in space (world-lock)
```

## Implementation order (linear; one commit per step)

### Step 1 — Move xr-driver to shared lib, expose config via dotfile

**Why first**: prerequisite for both single-host driver-mode change *and* multi-host import.

- `git mv system/users/jorge/dev/xr-driver system/lib/xr/driver` (folder rename only; package.nix and default.nix unchanged).
- `system/users/jorge/dev/default.nix`: change `./xr-driver` → `../../../lib/xr/driver`.
- New `dotfiles/default/xr_driver/config.ini`:
  ```ini
  disabled=false
  output_mode=external_only
  use_roll_axis=true
  ```
- `system/lib/dotfiles.nix`: add `${linkDir "xr_driver" "$cfg/xr_driver"}` next to the other `linkDir` calls (around line 89).
- `nixos-rebuild switch` on lewis. Verify:
  - `systemctl --user status xr-driver` → active (running).
  - `cat ~/.config/xr_driver/config.ini` shows the three lines above.
  - `xxd -l 1 /dev/shm/breezy_desktop_imu` byte 0 = `05` (DATA_LAYOUT_VERSION=5) — wear glasses if needed.
  - System cursor no longer drifts.

**Risk**: external_only mode might soft-require the breezy-vulkan companion. If `xr-driver` fails to start in this mode, mitigation is to leave `output_mode=mouse` AND add an `external` boolean flag — but read upstream's `driver.c` first to check whether SHM writes happen unconditionally or only in external mode. (Source check during impl, not now.)

### Step 2 — Package breezy-gnome

New `system/lib/xr/breezy-gnome/{package.nix,default.nix}` (template: copy `xr-driver/package.nix` style).

```nix
# package.nix sketch
stdenv.mkDerivation {
  pname = "breezy-gnome";
  version = "2.9.12";
  src = fetchFromGitHub {
    owner = "wheaney"; repo = "breezy-desktop";
    rev = "v2.9.12"; hash = lib.fakeHash;  # populate during impl
  };
  nativeBuildInputs = [ glib ];  # for glib-compile-schemas
  installPhase = ''
    ext=$out/share/gnome-shell/extensions/breezydesktop@xronlinux.com
    mkdir -p $ext
    cp -r gnome/src/* $ext/
    glib-compile-schemas $ext/schemas
  '';
}
```

`default.nix` exposes the package and (deferred to Step 3) wires it into the nested-shell launch. Don't enable the extension globally — only the nested session uses it.

Verify:
- Build succeeds.
- `ls $(nix-build -A ...)/share/gnome-shell/extensions/breezydesktop@xronlinux.com/` shows `metadata.json`, `extension.js`, `schemas/gschemas.compiled`.
- `metadata.json` `shell-version` array includes the GNOME-shell major version on host (`gnome-shell --version` in nix-shell with `gnome-shell` to confirm).

**Risk**: nixpkgs ships a GNOME shell version outside `[46..50]`. Mitigation: postPatch the array via `substituteInPlace metadata.json`. Cheap.

### Step 3 — `breezy-sideview` wrapper + nested-shell launch

New `system/lib/xr/breezy-sideview/{package.nix,default.nix}`.

`package.nix` writes a wrapper script (`writeShellApplication`) that:
1. Sets `MUTTER_DEBUG_DUMMY_MODE_SPECS=1920x1080@60` (matches glasses native resolution).
2. Sets a dedicated `XDG_RUNTIME_DIR=$XDG_RUNTIME_DIR/breezy-sideview`.
3. Constructs a nested `XDG_DATA_DIRS` containing the breezy-gnome derivation's `share/`, so `gnome-shell --nested` finds the extension by UUID.
4. `gsettings set org.gnome.shell enabled-extensions "['breezydesktop@xronlinux.com']"` for that runtime dir.
5. Apply preset (`--preset 2-screen` or `--preset 3-screen`) by setting `com.xronlinux.BreezyDesktop` schema keys before launch. **Verify exact key names during impl** by reading the extension's `schemas/*.gschema.xml` — likely candidates: `display-distance`, `display-spacing`, `virtual-display-count`. If schema doesn't expose count, drop 3-screen support to a follow-up.
6. `exec gamescope --backend=wayland --app-id breezy-sideview -- gnome-shell --nested --wayland`. Gamescope gives a stable Hyprland window class (`breezy-sideview`) that the windowrule in Step 4 can target. If gamescope wrap proves unnecessary (window class stable without it), drop it.
7. Trap SIGTERM → SIGTERM the child PID, then `wait`.

`default.nix` adds the wrapper to `environment.systemPackages` and sets:
- `services.logind.lidSwitchExternalPower = "ignore"` — lid close while docked + glasses doesn't suspend.

Verify:
- `breezy-sideview --preset 2-screen` opens a nested-shell window in Hyprland; breezy-gnome status icon appears in the nested top bar.
- Wear glasses, turn head: virtual surfaces stay world-locked.
- `pkill -TERM -f breezy-sideview` reaps cleanly (no orphan `gnome-shell` in `pgrep -af gnome-shell`).
- Lid close with external power: eDP-1 turns off, session keeps running.

**Risk**: nested mutter on wlroots needs DRM dummy mode and clean env. Common failure: black window or "no seat". Mitigation: gamescope wrapper above is the existing fallback path; if even gamescope can't host it, fall back to running gnome-shell directly without gamescope and accept whatever window class mutter chooses, then fix the windowrule to match.

### Step 4 — Hyprland keybinds + windowrule + disconnect handling

New `dotfiles/default/hypr/users/jorge/default/breezy.conf` (auto-sourced by the existing `**.conf` glob):

```
# Toggle sideview (2-screen preset). Re-running kills the existing instance via PID file.
bind = $mainMod, T, exec, breezy-sideview --toggle --preset 2-screen
bind = $mainMod SHIFT, T, exec, breezy-sideview --toggle --preset 3-screen
# Recenter head pose
bind = $mainMod, R, exec, xr_driver_cli --recenter
# Pin the nested-shell window to the glasses output
windowrulev2 = float, class:^(breezy-sideview)$
windowrulev2 = monitor desc:Technical Concepts Ltd SmartGlasses, class:^(breezy-sideview)$
windowrulev2 = fullscreen, class:^(breezy-sideview)$
```

The `--toggle` flag: wrapper checks `$XDG_RUNTIME_DIR/breezy-sideview.pid`; if alive, SIGTERM and exit; else launch and write pid.

Disconnect handling — script invoked from `exec-once = hyprctl monitors -j ...` via a small `hypr-monitor-watcher` (use existing event socket pattern). On `monitorremoved` for the glasses output: reap any sideview instance, migrate its workspaces back to `eDP-1`. Concrete script under `dotfiles/default/hypr/shared/scripts/breezy-monitor-watcher.sh` listening on `$XDG_RUNTIME_DIR/hypr/$HYPRLAND_INSTANCE_SIGNATURE/.socket2.sock`.

Verify:
- `Super+T` opens sideview at glasses-display coordinates; second press kills it cleanly.
- `Super+Shift+T` switches preset.
- `Super+R` triggers recenter (visible drift correction).
- Yank USB-C: glasses output disappears, sideview process gone, host Hyprland intact.

### Step 5 — Wire to verse / Jonas

- `system/users/eksno/dev/default.nix`: `imports = [ ./nixpacks.nix ./python.nix ../../../lib/xr/driver ../../../lib/xr/breezy-gnome ../../../lib/xr/breezy-sideview ];`
- New `dotfiles/default/hypr/users/eksno/default/breezy.conf` (mirror jorge's, but `monitor desc:` blank — verse may not have glasses connected during testing).
- `system/lib/dotfiles.nix` already universally links `xr_driver`, so eksno gets the config too.
- `nix build './#nixosConfigurations.verse.config.system.build.toplevel'` succeeds in sandbox.
- Send Jonas a one-paragraph note on update.sh + keybinds.

### Step 6 — Cleanup & memory updates

- Update `FIXES.md` 2026-05-04 entry: change "Air 3s Pro" → "Air 4 Pro" (model was misidentified earlier; PID `1bbb:af50` is correct for both, but the actual hardware is Air 4 Pro per Jorge). Add a short pointer entry referencing this plan's commits.
- Update `memory/user_glasses.md` (if present — verify; create if absent) with the corrected model and pointer.
- Add Jonas/`eksno` to `memory/` as cofounder + verse user (per draft).

### Step 7 — Soak (no code)

Jorge daily-drives for one week. Log papercuts to `FIXES.md` per the existing format. Anything that surfaces as a >P2 issue gets a standalone follow-up commit on `alpha`.

## Critical files (created or modified)

| File | Step | Action |
|---|---|---|
| `system/lib/xr/driver/{package.nix,default.nix}` | 1 | git-moved from `system/users/jorge/dev/xr-driver/` |
| `system/users/jorge/dev/default.nix` | 1 | import path updated |
| `dotfiles/default/xr_driver/config.ini` | 1 | new — `output_mode=external_only` |
| `system/lib/dotfiles.nix` | 1 | new `linkDir "xr_driver"` line |
| `system/lib/xr/breezy-gnome/{package.nix,default.nix}` | 2 | new derivation |
| `system/lib/xr/breezy-sideview/{package.nix,default.nix}` | 3 | new wrapper + logind override |
| `dotfiles/default/hypr/users/jorge/default/breezy.conf` | 4 | new keybinds + windowrules |
| `dotfiles/default/hypr/shared/scripts/breezy-monitor-watcher.sh` | 4 | new — handles glasses disconnect |
| `system/users/eksno/dev/default.nix` | 5 | imports added |
| `dotfiles/default/hypr/users/eksno/default/breezy.conf` | 5 | mirrored keybinds |
| `FIXES.md`, `memory/*` | 6 | model name correction + plan pointer |

## Stop-the-line conditions

Pause and rethink if any fire:

1. **Step 1**: `external_only` mode hard-requires breezy-vulkan (no SHM writes without it) — re-evaluate IPC contract; possibly add a vulkan-shim package or stay on `mouse` mode and patch the driver to also write SHM.
2. **Step 2**: nixpkgs GNOME version isn't in `[46..50]` and a metadata.json patch isn't enough — pin a different nixpkgs or accept partial feature loss.
3. **Step 3 / verify**: nested gnome-shell doesn't read SHM, OR virtual surface doesn't render world-locked (just a flat extra display) — IPC parity-byte assumption is wrong; revisit driver output mode and SHM ownership UID.
4. **Step 7 soak**: drift renders sideview unusable inside 30 min even with `Super+R` — re-evaluate the IMU pipeline; consider xr-driver's `smooth_follow` plugin.

## Out of scope (explicit)

- Multi-config layout-management system (auto-detect, presets, GUI authoring). Separate plan post-soak.
- Stereoscopic 3D / SBS mode on Air 4 Pro. Separate plan if Jorge wants it.
- Auto-launch on glasses connect. MVP is hotkey only.
- Cross-window dragging between sideview and host Hyprland. Nested gnome-shell is isolated by design.
- Privacy-mode indicator for screen-share.
- Audio routing tied to sideview state.
- `update.sh` AR-only fast-path.
- Hyprland-native plugin (Path 3). Only revisit if nested shell can't be made to work.

---

# Postmortem (added 2026-05-05)

This plan was executed through Step 4. The xr-driver work (Step 1) and the
breezy-gnome packaging (Step 2) landed cleanly and remain useful. Steps
3–4 hit a series of issues that culminated in a wall the plan couldn't
clear without a re-architecture.

## What landed

| Step | Status | Commits |
|---|---|---|
| 1: Move xr-driver to `system/lib/xr/`, add config.ini dotfile | ✅ | (incl. ExecStartPre install pattern instead of plain symlink) |
| 2: Package breezy-gnome v2.9.12 | ✅ | `a98666a` |
| 3: breezy-sideview wrapper + nested gnome-shell launch | ⚠️ wrapper builds, won't run | `36ac1c1` and ~6 follow-up fixes |
| 4: Hyprland keybinds + windowrule + disconnect watcher | ✅ keybinds load; windowrule rewritten three times for syntax churn | `81e20de`, `b4fe8e9`, `158f3b3`, `f59caba`, `0b04523` |
| 5: Wire to verse/eksno | ✗ not started |
| 6: FIXES.md cleanup + memory updates | ✗ not started (memory updated piecemeal during the session) |
| 7: Soak | ✗ blocked by Step 3 |

## What went wrong

**Root cause.** The plan assumed `gnome-shell --nested --wayland` works on
a non-GNOME wayland host. Two problems:

1. **GNOME 49 (`nixos-unstable`) removed `--nested`.** No working
   replacement on a Hyprland host — every other backend (`--display-server`,
   `--headless`, `--virtual-monitor`) tries to take logind seat control
   and fights Hyprland for it (`Failed to take control of the session: ...
   EBUSY`).
2. **GNOME 48 still has `--nested`, but it's nested-on-X11, not
   nested-on-Wayland.** Under Hyprland, that routes through XWayland and
   Clutter then can't init a GL backend (`no available drivers found`,
   trace shows `cogl-xlib-renderer.c`). Pinning gnome-shell to v48 via a
   separate flake input (`nixpkgs-gnome48`) didn't unblock this.

This was a **Stop-the-Line** that the plan correctly anticipated as a
risk in Step 3 ("nested mutter on wlroots needs DRM dummy mode and clean
env"), but the mitigation it proposed (gamescope wrap) didn't actually
address the real failure mode.

## What we paid for the lesson

The session also surfaced a long tail of independent issues, each
captured in `LEARNINGS.md`:

- xr-driver needs **both** `output_mode=external_only` AND
  `external_mode=breezy_desktop` for SHM writes (plan only specified the
  first).
- Hyprland 0.54 deprecated `windowrulev2`; modern syntax requires
  block-form with `name = ...` as the first key.
- nixpkgs schemas don't sit at `share/glib-2.0/schemas/`;
  `GSETTINGS_SCHEMA_DIR` is the right env var, not `XDG_DATA_DIRS`.
- `DCONF_PROFILE` as an absolute path triggers a null-objpath assertion;
  must be a profile name resolvable under `/etc/dconf/profile/`.
- `update.sh` re-bumps `flake.lock` every run — reverting locks is
  one-shot. Spawned `update-without-update.sh` for fast local iteration.
- `wifite2 → wireshark-cli` was a recurring closure-build blocker (broken
  upstream source hash); commented out for now.
- `services.logind.lidSwitchExternalPower` was renamed to
  `services.logind.settings.Login.HandleLidSwitchExternalPower` in
  unstable.
- `gnome-shell --nested` historical semantics were nested-on-X11, never
  nested-on-Wayland — the *only* pathway that ever worked for upstream
  breezy-gnome was launching from inside a real X server.

## What stays useful regardless of the next direction

- `system/lib/xr/driver/` — full Nix package + module for xr-driver,
  including patched udev rules and the config.ini install-on-restart
  pattern. Works.
- `system/lib/xr/breezy-gnome/` — clean Nix derivation of the upstream
  extension. Useful for any plan that hosts the extension somewhere
  (TTY-GNOME, sway, etc).
- `dotfiles/default/hypr/users/jorge/default/breezy.conf` — the keybind
  scaffolding and windowrule pattern. Re-targetable.
- `dotfiles/default/hypr/shared/scripts/breezy-{recenter,monitor-watcher}.sh`
  — flag-file-based recenter and disconnect handler.
- `update.sh` and `update-without-update.sh` improvements (Hyprland
  reload chained, no-flake-update variant for fast iteration).
- The `nixpkgs-gnome48` flake input (still wired; can be removed if a
  future plan doesn't use a pinned gnome-shell).

## What to revert if the next plan goes "Path 4" (park sideview)

A single-commit revert that strips just the sideview-specific work:

- `system/lib/xr/breezy-gnome/` (delete)
- `system/lib/xr/breezy-sideview/` (delete)
- `system/users/jorge/dev/default.nix` — drop the two new imports
- `dotfiles/default/hypr/users/jorge/default/breezy.conf` (delete)
- `dotfiles/default/hypr/shared/scripts/breezy-monitor-watcher.sh` (delete)
- `dotfiles/default/xr_driver/config.ini` — restore to
  `output_mode=mouse` and remove the `external_mode=breezy_desktop` line
- `flake.nix` — drop `nixpkgs-gnome48` input
- `flake.lock` — `nix flake lock --update-input nixpkgs-gnome48` to remove

xr-driver, the recenter script, the update-script improvements, and the
hyprland keybind layout pattern stay (they're not sideview-specific).
