# XR / sideview learnings

Topic-organized facts we've paid for. Append, don't replace. Each entry
should be terse but include the *why* — a future agent will be reading
this before debugging a similar issue.

---

## Architecture — GNOME-on-Wayland as a parallel SDDM-selectable session

After the nested-shell wall (next section), the working approach is:
register GNOME-on-Wayland as an additional session SDDM lists alongside
Hyprland. Hyprland keeps autologging in for daily use; pick "GNOME on
Wayland" in the SDDM greeter when you want world-locked breezy surfaces.
Logout boundary is the cost; everything else upstream supports already.

Concrete moving parts:

- `services.desktopManager.gnome.enable = true` puts
  `gnome-session-49.2-sessions` (an `overrideAttrs` of `gnome-session`
  that adds `share/wayland-sessions/gnome*.desktop`) into
  `services.displayManager.sessionPackages`. SDDM's NixOS-generated
  `SessionDir=/nix/store/<hash>-desktops/share/wayland-sessions` then
  surfaces both `gnome.desktop` and `gnome-wayland.desktop`.
- `desktopManager.gnome.enable` flips on `displayManager.gdm.enable`
  transitively. `lib.mkForce false` is required to keep SDDM as the DM.
  The non-mkForce form silently loses the priority fight.
- The bare `gnome-session` derivation does NOT ship the wayland session
  `.desktop` file — only the `-sessions` override does. If you ever
  inspect the closure and don't see GNOME sessions, check
  `services.displayManager.sessionPackages` for the `-sessions` package,
  not the bare one.

## dconf seeding for first-login defaults

`programs.dconf.profiles.user.databases` adds a system-db entry to the
`user` profile (NixOS prepends `user-db:user`, then appends each entry
as `system-db:`). This makes `dconf-keyfile` the deployment shape for
"GNOME login defaults" without `home-manager`.

Gotchas:

- `lib.gvariant.mkArray [ "x" ]` is required for typed string lists
  (`as`). A bare `[ "x" ]` may serialize ambiguously. Doubles and bools
  pass through unwrapped.
- Nested-key paths (e.g. custom-keybindings entries) need the parent
  key's array to list the trailing-slashed object path AND a separate
  attrset entry at the deeper path. Both are required for
  gnome-settings-daemon to pick up the binding.
- `lockAll = true` would lock the seeded values from user override —
  don't set unless you want to take away gnome-control-center
  configurability.

## Architecture — nested gnome-shell on Hyprland is impossible

**The premise of the original plan was wrong.** Mutter's `--nested` flag
historically meant "nested as an X11 client", *not* nested-on-Wayland.
On Hyprland (no real X server), `--nested` routes through XWayland and
Clutter then fails to initialize ("no available drivers found") because
the XWayland-GLX path is broken in our stack.

- v49 removed `--nested` from gnome-shell entirely. There is no
  documented replacement that works on a non-GNOME wayland host —
  `--display-server`, `--headless`, and `--virtual-monitor` all force a
  full display server which then loses the seat-control fight to
  Hyprland (`Failed to take control of the session: ... EBUSY`).
- v48 still has `--nested`, but the same Clutter failure applies under
  Hyprland (`cogl-xlib-renderer.c:281: Outputs:` in the trace).
- We tried: pinning gnome-shell to v48 via a separate flake input
  (`nixpkgs-gnome48` → `nixos-25.05`), preserving the `--nested`
  invocation. Same EBUSY/clutter failure. The pin is still in place but
  doesn't unblock the path.

**Implication.** Every variant of "nested compositor on Hyprland" is a
dead end without major upstream or downstream work. Realistic paths
forward are tracked in `PLAN.md` (TTY-swap, wlroots-native breezy,
parking sideview). Do not try `gnome-shell --nested` on Hyprland again.

---

## XR driver — IPC contracts

### Breezy_desktop SHM writer is paywalled by upstream

The breezy_desktop plugin (`src/plugins/breezy_desktop.c`,
`handle_config_line_func`) gates `bd_config->enabled` on
`is_productivity_granted()` in addition to `external_mode=breezy_desktop`.
`is_productivity_granted()` checks for `"productivity"` or
`"productivity_pro"` in `state()->granted_features`, which is populated
from the device license JSON's `tiers` field. The license is signed
against `license_public_key.pem` baked into the driver binary.

**Free-tier license (`"tiers":{}`) → SHM file is never created** even
though the driver runs cleanly, connects to the glasses, calibrates,
and produces `/dev/shm/xr_driver_state`. The breezy GNOME extension
silently shows nothing (no top-bar icon) because `IPC_FILE_PATH`
(`/dev/shm/breezy_desktop_imu`) doesn't exist to poll.

Symptoms when this is the actual blocker:
- `gnome-extensions list --enabled` includes `breezydesktop@xronlinux.com`
- `xr_driver_state` shows `calibration_state=CALIBRATED`
- `ls /dev/shm/` shows `xr_driver_state` and `xr_driver_control` but
  NOT `breezy_desktop_imu`
- `~/.local/state/xr_driver/<hwid>_license.json` has `"tiers":{}`
- No log line in `~/.local/state/xr_driver/driver.log` mentions breezy
  (because the plugin's open call short-circuits before any
  `breezy_desktop:` prefixed log)

Resolution paths:
1. Buy a productivity tier from https://breezy-desktop.com/ — the
   license auto-refreshes; restart xr-driver after purchase to pick
   up the new tier.
2. Fall back to glasses-as-cursor: set `output_mode=mouse` in
   `dotfiles/default/xr_driver/config.ini`. Free, no world-lock.
3. Fork the driver and strip the gate. Possible but maintenance-heavy
   and likely against upstream license terms.

### `output_mode=external_only` alone does NOT enable SHM pose writes

The breezy_desktop plugin (XRLinuxDriver `src/plugins/breezy_desktop.c:73`)
gates SHM writes on `external_mode` *containing* `breezy_desktop`. Both
keys are required:

```ini
output_mode=external_only
external_mode=breezy_desktop
```

With only the first set, the driver connects to the glasses, populates
`/dev/shm/xr_driver_state` (heartbeat, calibration state, hardware id),
but never creates `/dev/shm/breezy_desktop_imu`. Upstream's
`xr_driver_cli --breezy-desktop` writes both keys atomically.

Verified on lewis 2026-05-05.

### Recenter via flag-file IPC, no CLI

There is no `xr_driver_cli` binary in our package output (we only ship
`xrDriver`). Recenter is triggered by writing the IPC control file:

```bash
printf 'recenter_screen=true\n' > /dev/shm/xr_driver_control
```

The driver polls this file (`src/state.c:33`,
`control_flags_filename = "xr_driver_control"`), recognizes a small set of
keys including `recenter_screen` and `recalibrate`, and resets after.

Implemented as `dotfiles/default/hypr/shared/scripts/breezy-recenter.sh`
on Super+R.

### USB-C cable matters

Glasses can enumerate as a single bare USB interface (HID class only,
USB 1.1 full-speed) over a power-only or partial USB-C cable. They
appear in the kernel log as `RayNeo AR Glasses` with a single endpoint
pair, no DP alt-mode, no video class. xr-driver still works for IMU/HID
through this — the cable problem is only relevant if you wanted display
output too (which sideview doesn't need anyway, since it runs on the
laptop screen).

If `lsusb` ever shows the glasses but `/dev/hidraw*` doesn't gain a new
node, suspect the cable next, not the driver.

### Cable can ALSO be ruled in/out with a phone test

If the same cable+glasses combination successfully enters DP altmode on
a phone (visible content on the glasses panel), the cable is not the
blocker for the laptop's missing altmode. Phones run more permissive
USB-C altmode policies than laptop UCSI/TBT4 stacks; "works on phone"
only proves the cable can carry DP altmode at all, not that it
satisfies the laptop's stricter cable-classification requirements.
But it does conclusively rule out hard cable failure as a cause when
the laptop refuses altmode.

### UCSI/EC altmode wedge survives soft AND hard reset paths on lewis

Discovered 2026-05-08 on lewis (ASUS Zenbook 14 UX3405MA, BIOS
UX3405MA.301). After heavy plug/unplug cycling the EC firmware can
reach a state where it reports the partner correctly (PD2 negotiated,
`partner_flags=2 = altmode capable`) and even returns the partner's
DP altmode SVID `0xff01` from `GET_ALTERNATE_MODES`, but
`GET_CAM_SUPPORTED` returns 0 and `SET_NEW_CAM` times out. The kernel
never calls `ucsi_register_altmodes` because the EC never sets the
`UCSI_CONSTAT_CHANGE_CAM` (bit 10) flag in its connector-change
events.

Things that **don't** clear this wedge:

- Cable orientation flip / port swap
- `ucsi_acpi` driver unbind/rebind
- xhci PCI device unbind/rebind
- 5-min glasses unplug for capacitor discharge
- `usbcore.autosuspend=-1` runtime
- `systemctl suspend` + wake
- `sudo reboot`
- Cold cycle (full shutdown + AC unplug + 30s power-button hold)
- UCSI `CONNECTOR_RESET` (soft and hard variants 0x03 / 0x03|bit23)
- UCSI `SET_NEW_CAM` (kernel-blocked / EC times out)
- UCSI `PPM_RESET` (kernel-blocked: "Operation not supported")
- UCSI `SET_NOTIFICATION_ENABLE` (same kernel block)
- BIOS Restore Defaults (F2 → F9 → F10) — VERIFIED 2026-05-08

The EC altmode policy state lives in NVRAM that BIOS Restore Defaults
doesn't reach. Remaining theoretical recovery paths:

- **Long idle wait** — some EC firmware bugs self-clear after hours/days
  of no USB-C activity. Untested duration.
- **Battery-disconnect pinhole** — if the laptop has one (Zenbook 14
  models vary). Most aggressive non-flash reset.
- **BIOS firmware update** — flashing newer firmware almost always
  resets EC NVRAM as a side effect, regardless of code differences.
- **Try the laptop without the kernel power-saving cmdline params**
  (`i915.enable_dc=4`, `pcie_aspm=force`, `acpi.ec_no_wakeup=1`,
  `usbcore.autosuspend=1`) — these were active when the wedge first
  triggered. Removing them and rebooting might allow the EC to
  re-evaluate. Untested.

**Diagnostic recipe** (5 UCSI commands, 30 seconds) to fingerprint this
specific wedge is in `memory/xr-lewis-ec-refuses-altmode.md`.

### NixOS + Secure Boot is not configured by default

If you ever run "Restore Defaults" in BIOS, secure boot will be re-enabled
and NixOS won't boot (the `\EFI\nixos\*` bootloader entries aren't signed
against the OEM/Microsoft keys secure boot expects). Symptom: BIOS skips
NixOS and falls through to whatever else is in the boot order (Ubuntu
fallback, USB stick, etc.). Disable secure boot in BIOS to recover.

To make NixOS work with secure boot, enable
[`lanzaboote`](https://github.com/nix-community/lanzaboote) — it signs
the bootloader entries with a self-managed key. Not currently set up
on lewis or verse.

---

## NixOS plumbing — schemas and dconf are awkward off-the-beaten-path

### gnome-shell schemas are not at `share/glib-2.0/schemas/`

nixpkgs installs them at
`share/gsettings-schemas/<pkg>-<ver>/glib-2.0/schemas/`. Plain
`XDG_DATA_DIRS=<pkg>/share` does not surface them to gsettings (gsettings
expects each entry to have `glib-2.0/schemas/<name>.gschema.xml` directly
under it). On a non-GNOME host, `gsettings set org.gnome.shell ...` then
fails with `No schemas installed`.

`GSETTINGS_SCHEMA_DIR=<colon-list of compiled schema dirs>` works around
this — set it to the deeper path, e.g.
`${gnome-shell}/share/gsettings-schemas/gnome-shell-${gnome-shell.version}/glib-2.0/schemas`.

### `breezy-gnome` schema lives even further off-path

The extension's own schema (`com.xronlinux.BreezyDesktop`) installs at
`share/gnome-shell/extensions/breezydesktop@xronlinux.com/schemas/`,
where gnome-shell extensions are *expected* to keep their schemas. But
that path is NOT covered by either `XDG_DATA_DIRS` or the standard
gsettings schema lookup. To call gsettings/dconf against keys in this
schema from a non-extension context, point `GSETTINGS_SCHEMA_DIR` at
this directory directly.

### `DCONF_PROFILE` as an absolute path triggers a null-objpath assertion

```
DCONF_PROFILE=/path/to/file dconf write /test/foo "'bar'"
```

aborts with:

```
GLib-GIO-CRITICAL: g_dbus_connection_call_sync_internal:
  assertion 'object_path != NULL && g_variant_is_object_path (object_path)' failed
ERROR:../bin/dconf.c:1200:main: assertion failed: (error != NULL)
```

dconf appears to compute an empty dbname when the profile is given as a
path (versus a name resolved under `/etc/dconf/profile/<name>` or
`$XDG_CONFIG_DIRS/dconf/profile/<name>`). Default profile (no override)
or a system-installed named profile both work. For path-based isolation
you'd need to drop a profile file under `/etc/dconf/profile/<name>` from
a NixOS module and reference it by name.

### Mixing nixpkgs versions for graphics-heavy packages is risky

Pinning `gnome-shell` to `nixos-25.05` and the rest of the closure to
unstable evaluates and builds, but the resulting mutter (linked against
25.05 mesa/libglvnd/libdrm) failed to initialize Clutter on a system
where the runtime drivers come from unstable. Specifically: the
`__GLX_VENDOR_LIBRARY_NAME=nvidia` env var (leaked into Jorge's session
from `nvidia-offload.sh`, even though lewis is Intel) was a red herring;
the real issue was Clutter selecting the X11 backend under XWayland and
GLX failing.

If you ever cross-pin a graphics-stack package, expect to also pin or
adjust LD_LIBRARY_PATH / driver paths.

---

## Hyprland 0.54 — config syntax churn

### `windowrulev2` is deprecated; use `windowrule`

Hyprland 0.54 keeps the same one-line filter syntax under the new name.
Old:

```
windowrulev2 = float, class:^(foo)$
```

New (one-line equivalent):

```
windowrule = match:class foo, float
```

But the one-line form **does not accept bool-flag actions** like
`float`/`fullscreen` — they need a value, e.g. `float true`. Easier to
use the **block form**, which is what the rest of this repo uses:

```
windowrule {
  name = my-rule-name        # REQUIRED — first key, or "first value must be the key" error
  match:class = ^(foo)$
  float = true
  fullscreen = true
  monitor = desc:Some Monitor
}
```

Block-form `windowrule` is a "special category" and the parser
**requires `name = ...` as the first key**. Without it, Hyprland
rejects the block.

### Keybinds in `dotfiles/default/hypr/users/jorge/default/*.conf` are auto-sourced

The user's `~/.config/hypr/users/jorge/default.conf` does
`source = ~/.config/hypr/users/jorge/default/**.conf`, so any new `.conf`
in that dir is picked up on next `hyprctl reload`. No need to add the
file to a manifest. New dotfiles still need a `nixos-rebuild` for the
*symlink* to be created (the activation script handles that), but
existing symlinked dirs reflect the file-tree changes immediately.

---

## Update / rebuild flow

### `update.sh` always re-bumps `flake.lock`

Reverting `flake.lock` to fix a transient upstream issue (e.g. wireshark
source-hash mismatch) is a one-shot — the next `update.sh` run executes
`nix flake update` and the bump comes back. Either:

- Keep the workaround durable in code (e.g. comment out the offending
  package — see `wifite2` removal in
  `system/users/{jorge,eksno}/programs/default.nix` and
  `FIXES.md` 2026-05-05 entries), or
- Use `update-without-update.sh` for fast local iteration (no flake
  bump), and only run `update.sh` when you actually want upstream
  package updates.

### `nixos-rebuild switch` failures don't fail `update.sh`

`update.sh` doesn't `set -e`. A failed `nixos-rebuild switch` flows
through to the trailing `df -h /boot` and the script exits 0. If you
think a switch happened but `/run/current-system` still points at the
old generation, the switch silently failed. Run `nixos-rebuild switch
--flake ./#$HOST --impure` directly to see the real error.

### Restarting xdg-desktop-portal-* mid-session destabilizes Hyprland

`update.sh` reloads user services on rebuild, including
`xdg-desktop-portal-*`, `pipewire`, `dbus-broker`. Active Wayland
sessions don't always recover cleanly — Jorge has had to reboot after
update.sh runs that touched these services. Use `update-without-update.sh`
for low-churn rebuilds; reboot after big package bumps.

### `git add .` sweeps in unintended files

`update.sh` runs `git add .` to make untracked files visible to Nix.
This regularly catches files that should be gitignored (e.g.
`.claude/scheduled_tasks.lock`). When this happens, untrack and
gitignore them — don't manually unstage in a future commit, because
`git add .` just resurrects them.

---

## Architecture — open-source Hyprland breezy via Monado + WayVR

The 2026-05-05 GNOME-Breezy session pipeline got all the way to the
breezy_desktop GNOME extension loading, then hit the upstream
`is_productivity_granted()` SHM gate (see "Productivity-tier license
gate" in STATE.md). With Jorge's "no GNOME, no paying" constraint,
the open-source replacement is:

  Monado (patched with MR !2737 for Rayneo) → WayVR via OpenXR

`monado-rayneo` overrides nixpkgs `monado` with the head SHA of
gitlab.freedesktop.org/monado/monado/-/merge_requests/2737. Stock
Monado does NOT enumerate the Rayneo Air 4 Pro — its `xreal_air`
builder only matches XREAL VID 0x3318. MR !2737 adds a dedicated
`rayneo` driver for USB `1bbb:af50`, tested on Air 4 Pro hardware,
pipeline green, AI-generated but functional. Reference SHA:
`4b8d4a81328e8240a180aad6f70337ac691d9cbf` (2026-05-05).

When wrapping it: filter nixpkgs' `monado-cylinder-aspectRatio.patch`
because the MR is post-25.1 and already includes the upstream commit
that patch backports. Without the filter, `nixos-rebuild` fails with
"Reversed (or previously applied) patch detected. Skipping patch."

WayVR (formerly WlxOverlay-S) is `wayvr-org/wayvr` — the rename is
recent enough that older docs / Claude knowledge may still reference
`galister/wlx-overlay-s` or `galister/wayvr`. The latter is a
different/old/dead project; do not use it. WayVR 26.2.1 is in
nixpkgs as `pkgs.wayvr`. **No fork required** — the optional
nested-Smithay-compositor mode it had has been made truly optional
upstream, so we get a working OpenXR overlay client for free.

## monado-service launcher: stdin must be a pollable, persistent pipe

`monado-service` registers stdin in its epoll mainloop (parent-process
death detection at `src/xrt/ipc/server/ipc_server_process.c:360`).
This places three constraints on launchers:

1. **TTY stdin fails.** epoll_ctl(stdin) returns -1; `init_all` then
   bails with `XRT_ERROR_IPC_MAINLOOP_FAILED_TO_INIT`. Running
   `monado-service` directly from a fish/bash terminal hits this
   every time — even though you'd expect the controlling TTY to be
   pollable.

2. **`/dev/null` also fails.** Char devices don't implement `poll()`;
   epoll rejects them with the same error path.

3. **Pipes work — but must stay open.** `true | monado-service` succeeds
   at init (the pipe IS pollable) but exits cleanly the moment `true`
   returns and EOF reaches monado — interpreted as "parent died, time
   to shut down." Result: clean `Server exiting: '0'` right after
   Vulkan init, no diagnostic output beyond the swapchain log lines.

The working pattern is `sleep infinity | monado-service` — pollable
AND never EOFs. systemd hands monado a pipe that stays open for the
unit's lifetime, which is why systemd-launched runs don't hit this.
Our launcher in `system/lib/xr/breezy-hyprland/launcher.nix` uses the
sleep-infinity pattern; the EXIT trap reaps both monado AND the sleep
on cleanup.

## XR_RUNTIME_JSON must be set in the launcher's own env

`environment.variables.XR_RUNTIME_JSON =
"${monadoRayneo}/share/openxr/1/openxr_monado.json"` is correct as a
system-level setting, but it only takes effect on the next login
(re-source of `/etc/profile`). For a tool that's meant to work
immediately after `nixos-rebuild switch`, the launcher must
`export XR_RUNTIME_JSON=...` in its own process, with the path baked
in at nix-eval time so /nix/var rebuilds invalidate it correctly.
Otherwise the OpenXR loader emits "failed to determine active runtime
file path for this environment" → `XR_ERROR_RUNTIME_UNAVAILABLE`.

## Hyprland holds the glasses connector → Monado falls back to windowed mode

When Monado tries direct DRM mode (`comp_window_direct_wayland_init`),
it logs `Available DRM lease device: /dev/dri/card1` then
`Found no connectors available for direct mode` because Hyprland
already drives the SmartGlasses connector via wlroots.

In windowed mode, Monado opens a 3840x1080 Wayland surface (stereo
SBS pack) somewhere on the user's compositor. Side-effects observed:
  - Hyprland's no-response watchdog flags the window ("Application
    Not Responding: Monado - openxr") because monado doesn't pump its
    Wayland event loop fast enough during render
  - Glasses display the SBS frame's left half stretched across one eye
    and undefined buffer (rainbow vertical lines) on the other
  - SIGKILLing monado mid-frame leaves DRM state half-released —
    Hyprland can drop monitors from its list until the user replugs

## wlroots only advertises non-desktop outputs via wp-drm-lease-v1

**`hyprctl keyword monitor "desc:..., disable"` does NOT make the
connector available to Monado for DRM lease.** This was the original
Phase 3 plan; tested 2026-05-06, confirmed wrong.

Mechanism: `wp-drm-lease-v1` is the Wayland protocol monado uses to
request a DRM lease from the compositor (verified in monado source
at `src/xrt/compositor/main/comp_window_direct_wayland.c`). The
protocol design only has the compositor advertise outputs that have
the **DRM `non_desktop` connector property** set — typically VR
headsets (Index, Vive, Beyond) whose EDID flags them as non-desktop
displays. wlroots follows the protocol literally and only exposes
non-desktop connectors. Hyprland inherits this from wlroots and
hasn't extended it.

The Rayneo Air 4 Pro's EDID **does not set the non-desktop bit** —
it identifies as a regular 1920x1080 monitor. Result: no matter
what we do with `hyprctl keyword monitor` (disable, preferred,
mirror, anything), the SmartGlasses connector is never advertised
on the lease device, and monado always falls back to direct-Wayland
or Wayland-windowed mode.

What's worse: with `disable`, monado fails the Wayland-windowed
fallback too (no Wayland output to bind a surface to) and exits
within ~2 seconds of init with `Server exiting: '0'`. The result
is **strictly worse** than not toggling the monitor — without the
disable, monado at least reaches FOCUSED and (incorrectly) renders
to the compositor.

The 2026-05-06 launcher therefore does NOT toggle the monitor.
Real fix paths for direct DRM lease:

  1. **EDID override (cleanest):** add `drm.edid_firmware=DP-2:edid/glasses.bin`
     to the kernel cmdline, with a copy of the glasses' EDID modified
     to set the non-desktop bit (DisplayID block / extension bit).
     Hyprland would then auto-expose the connector for lease and
     monado picks it up. Tradeoff: glasses are non-desktop *all the
     time*, even when monado isn't running (they wouldn't appear as
     a regular Hyprland monitor for mirror/extend use). For an
     XR-first workflow this is fine.
  2. **Patch wlroots/Hyprland** to expose all manually-disabled
     outputs for lease. More invasive, follows the spirit of "VR
     mode" toggle.
  3. **Don't use direct DRM lease at all** — find a Wayland-windowed
     mode flow where the SBS-packed surface lands correctly on the
     glasses output. Likely requires the glasses to be in their
     custom 3840x1080 SBS mode (HID toggle), and Hyprland to
     fullscreen monado's window on that output. Complexity unclear.

## OpenXR session reaches FOCUSED ≠ user sees the right thing

WayVR walking the OpenXR session through IDLE → READY → SYNCHRONIZED
→ VISIBLE → FOCUSED with non-zero IPD reports just means the OpenXR
plumbing succeeded — pose data flowing, view configuration negotiated.
It does NOT mean the user is seeing rendered VR content correctly.
Independent verification needed: actual visual confirmation by Jorge
wearing the glasses.

In the 2026-05-05 test the session reached FOCUSED but Jorge saw
half-rendered + rainbow bars — symptoms of the windowed-mode problem
above, not an OpenXR session issue. The log progression "looks fine"
even when the rendered output is wrong.

## WayVR's GUI is built around 6DoF + dual controllers

WayVR is designed for SteamVR-class setups: room-scale 6DoF +
Vive/Index/Oculus controllers. For 3DoF AR glasses with no
controllers, the relevant config is **Handsfree mode**: dashboard /
settings / controls (or the keyboard's hamburger menu temporarily,
per github.com/wayvr-org/wayvr/issues/437).

WayVR doesn't natively understand "I am running on AR glasses, not in
a VR room." Defaults assume a virtual world to populate; pass-through
must be enabled (it is by default in OpenXR mode), screens must be
explicitly placed via the dashboard.

Loaded interaction profiles (vive, index, touch, microsoft, hp, etc.)
emit WARN lines in the wayvr log even on a controller-less setup —
those are not errors, just unused profile loads. Filter them out
when grepping for real errors.

## Glasses cable USB unplug during render → Rayneo USB read errors

`ERROR [rayneo_phase_running] USB read error in streaming mode` in
the monado-service log indicates the Rayneo USB stream got
interrupted — typically from unplugging the glasses cable mid-run.
Not a driver bug. After replug, monado-service needs a restart to
re-open the device.

## EDID override + non-desktop = wlroots advertises lease as expected

The Microsoft HMD VSDB approach in `xr/edid/patch_glasses_edid.py`
works end-to-end: at boot, kernel loads the override EDID, parses
the Microsoft VSDB (OUI 0x5C 0x12 0xCA), sets
`connector.non_desktop = true`. wlroots then advertises the
connector via `wp-drm-lease-v1`. Verified on lewis 2026-05-06:

- `nix run nixpkgs#drm_info` shows DP-2's "non-desktop" property = 1
  (was 0 pre-override).
- `/sys/class/drm/card1-DP-2/non_desktop` does NOT exist on kernel
  7.0.3 — the property is queryable via DRM ioctl (drm_info uses
  this) but isn't exposed as a sysfs file. Don't trust the absence
  of the sysfs file as a signal of failure.
- `hyprctl monitors` (without `all`) excludes DP-2; `hyprctl
  monitors all` lists it but with no active mode (`0x0@60`) and no
  `mirrorOf:` line. That's the success signal — Hyprland is
  enumerating it as a known-but-not-managed output.
- monado log on launch:
  `INFO [_lease_connector_done] [/dev/dri/card1] connector DP-2
  (Technical Concepts Ltd SmartGlasses 0x00000011 (DP-2)) id: 528`
  — lease accepted via the protocol.

Rollback (e.g., wanting to use the glasses as a regular external
monitor) is removing the `glasses-edid` import in
`system/hosts/lewis/default.nix` and rebuilding+rebooting.

## USB device ACL boot-race: `uaccess` only fires when logind is up

The xr-linux-driver udev rules use `TAG+="uaccess"` to grant
per-session ACLs to whoever owns the active seat. systemd-logind
processes the tag and sets `user:<jorge>:rw-` on the device node.
**This only works if logind is running when the udev event fires.**

For devices enumerated at boot (USB hubs, peripherals plugged in
during POST), the kernel/udev event happens BEFORE logind starts
its session-tracking. Result: device shows `TAGS=:uaccess:seat:`
in udevadm but `CURRENT_TAGS=:seat:` (no uaccess), and `getfacl`
shows no per-user ACL — only the static `MODE="0660"` root:root.
Non-root user gets EACCES on `open()`.

How to detect: `cat /dev/bus/usb/<bus>/<dev>` as user → "Permission
denied"; `udevadm info /dev/bus/usb/<bus>/<dev>` shows uaccess in
TAGS but missing from CURRENT_TAGS.

Quick workaround: physically unplug + replug the device. The fresh
ACTION=="add" event fires with logind already running, so the
ACL applies.

Permanent fix (`system/lib/xr/glasses-edid/default.nix`): override
the upstream rule with `services.udev.extraRules` setting
`MODE="0660", GROUP="users"`. Any user in `users` group gets stable
access independent of logind state. Don't broaden to `MODE="0666"` —
unnecessary attack surface for what's just a USB hot-plug bug.

## VkDisplaySurfaceKHR fails on wlroots-leased connector (Mesa anv + Intel Arc)

End state of Phase 3 attempt 2026-05-06: monado successfully takes
a wp-drm-lease-v1 lease on DP-2 (confirmed by `_lease_connector_done`
log line), then immediately on the first frame:

```
ERROR [renderer_present_swapchain_image] vk_swapchain_present: VK_ERROR_SURFACE_LOST_KHR
ERROR [renderer_acquire_swapchain_image] comp_target_acquire: VK_ERROR_SURFACE_LOST_KHR
```

DRM state in `drm_info` confirms no scanout was set up:
- `"DPMS"` = Off
- `"CRTC_ID"` = 0 (no CRTC bound)
- non-desktop=1 (correctly inherited from EDID)

Wayvr's OpenXR session still walks IDLE→READY→SYNCHRONIZED→VISIBLE→
FOCUSED with IPD = 63mm, so the protocol plumbing is fine — but no
pixels ever reach the connector. Glasses display black even after
replug.

### Verified: monado IS using `VK_EXT_acquire_drm_display`

`comp_window_direct_wayland.c` in monado-rayneo (MR !2737 head SHA
4b8d4a8) builds with `#error "Wayland direct requires the Vulkan
extension VK_EXT_acquire_drm_display"` and the runtime path goes:
1. `_lease_fd` callback receives leased FD from wp_drm_lease_v1
2. `vkGetDrmDisplayEXT(physical_device, drm_fd, connector_id, &vk_display)`
3. `vkAcquireDrmDisplayEXT(physical_device, leased_fd, vk_display)`
4. `comp_window_direct_create_surface(base, vk_display, w, h)` →
   `vkGetPhysicalDeviceDisplayPlanePropertiesKHR` → `vkCreateDisplayPlaneSurfaceKHR`
   → `vkCreateSwapchainKHR`
5. First `vkQueuePresentKHR` → `VK_ERROR_SURFACE_LOST_KHR`

So the bug is downstream of `VK_EXT_acquire_drm_display`. monado
gives Mesa the leased display correctly; Mesa accepts the surface
and swapchain creation; first present fails.

### Confirmed: Mesa anv direct-display path is broken on Intel Arc

`vulkaninfo` warns:
```
ICD for selected physical device does not export vkGetPhysicalDeviceDisplayPlanePropertiesKHR!
ICD for selected physical device does not export vkGetPhysicalDeviceDisplayPropertiesKHR!
```

`vkcube --wsi display` (vulkan-tools) confirms it from the other
direction — fails immediately with "Cannot find any display!" on
both Intel Arc (`--gpu_number 0`) and llvmpipe (`--gpu_number 1`),
even with xr-driver stopped and the EDID override making DP-2 a
leasable non-desktop output.

Net: Mesa's anv driver advertises `VK_KHR_display`,
`VK_EXT_direct_mode_display`, `VK_EXT_acquire_drm_display` as
**instance** extensions (loader-level), but the `VK_KHR_display`
**device** functions (`vkGetPhysicalDeviceDisplayPlanePropertiesKHR`,
`vkGetPhysicalDeviceDisplayPropertiesKHR`) aren't actually
implemented in the Intel ICD. The acquire path works because
`VK_EXT_acquire_drm_display` is instance-level; the swapchain path
falls over because the device-level display plane code path is
unimplemented.

This is a Mesa gap, not something we can config-fix.

### Forward options (none cheap)

1. **Patch Mesa anv** to wire up display plane support on top of
   the existing KMS modesetting code. Probably ~hundreds of LOC.
   Out of scope for breezy-hyprland.
2. **Stay in Wayland-windowed mode** (Phase 2 path) but solve the
   SBS visual: needs the rayneo HID "enter 3D mode" command +
   either a 3840x1080 custom DRM mode on DP-2 (unlikely without
   additional EDID work) or the glasses interpreting a 1920x1080
   surface as half-and-half (which they don't natively).
3. **Different OpenXR runtime** that doesn't require display
   plane API — e.g., something that draws into a regular Wayland
   surface via XR composition layers and relies on the host
   compositor for output. Stoja, WayVR's nested-Smithay mode,
   etc. Most still depend on monado though.
4. **Use a different GPU.** A laptop with NVIDIA + the proprietary
   driver supports VK_KHR_display direct mode out of the box for
   VR/AR. Not a fix for `lewis` (Intel-only).

For now: Phase 3 architectural work is committed (EDID override,
USB ACL fix, launcher hygiene); visual rendering blocked on the
Mesa gap. The committed config is a strict superset of what
worked at Phase 2 — running breezy-hyprland with the override
active gets the lease but black glasses; reverting the
glasses-edid import returns to Phase 2 behavior (Wayland-windowed,
half-rainbow but visible).

## Correction (2026-05-06): the "Mesa anv display-plane gap" claim above is WRONG

The "Confirmed: Mesa anv direct-display path is broken on Intel Arc"
section above was based on misreading a `vulkaninfo` warning. Two
checks killed it:

1. The vulkaninfo warning was emitted by the **dzn** ICD (which
   crashes during init), not anv. Setting
   `VK_DRIVER_FILES=/path/to/intel_icd.x86_64.json` to force the
   Intel ICD made the warning vanish. The "missing display plane
   functions" message belonged to a totally different ICD.
2. `libvulkan_intel.so` strings include the full `wsi_display_*`
   symbol family: `wsi_display_setup_crtc`, `wsi_display_setup_connector`,
   `_wsi_display_queue_next`, `wsi_display_queue_present`,
   `drmModeAtomicCommit`, `VK_ERROR_SURFACE_LOST_KHR`. Mesa anv DOES
   implement device-level display WSI; mesa source `wsi_common_display.c`
   has zero anv-vs-radv asymmetry.

Don't repeat that diagnosis. See `memory/process-verify-before-recommend.md`.

## breezy-hyprland launcher race: stale monado_comp_ipc socket (FIXED)

The launcher's socket-wait loop was checking `[[ -S "$SOCK" ]]` and
breaking immediately if `$XDG_RUNTIME_DIR/monado_comp_ipc` existed.
A stale socket from a previous run satisfied the check. Wayvr then
launched before monado-service finished init, got `Connection
refused`, exited clean, and the EXIT trap killed monado mid-frame.

This LOOKED like a SURFACE_LOST from monado but was actually a
launcher race causing premature shutdown. Fix: `rm -f` the stale
socket alongside the existing `rm -f` for `monado.pid`. Commit
`f74154b` + FIXES.md entry.

Diagnostic that caught it: v3 (`.scratch/diagnose-surface-lost/run-v3-nosudo.sh`)
ran for 15s with verbose env. monado log ended with `Server exiting:
'0'` and breezy-stdout showed `Failed to connect to socket
/run/user/1000/monado_comp_ipc: Connection refused!` from wayvr.

## v2 diagnostic with kernel `drm.debug=0x1f`: kernel-side modeset DOES succeed

`echo 0x1f | sudo tee /sys/module/drm/parameters/debug` plus
`sudo dmesg -t` after the run captures the full atomic-check trace.
Run window:

- monado-service issues `DRM_IOCTL_MODE_ATOMIC` exactly once per swapchain present
- `intel_atomic_check` passes — full mode setup runs (CDCLK, DPLL,
  plane state)
- DP link training: `Channel EQ done. DP Training successful`,
  `Link Training passed at link rate = 270000, lane count = 4`
- `intel_enable_transcoder enabling pipe C`
- `intel_audio_codec_enable [CONNECTOR:528:DP-2]`
- `verify_connector_state [CONNECTOR:528:DP-2]` — clean
- **No EINVAL, no atomic_check rejection, no error returns** from
  monado-service ioctls during the run

Where SURFACE_LOST originates: NOT kernel-side rejection. Suspects:
Mesa-internal page-flip event timing, syncobj/fence ordering, or a
follow-up commit Mesa issues that fails. The intermittency (one v3
run hit steady-state 65 frames clean; subsequent runs all SURFACE_LOST
on first present) supports a race-condition hypothesis.

## Glasses SBS-mode HID toggle via xr-driver control IPC

`/dev/shm/xr_driver_control` accepts:
```
sbs_mode=enable     # 3D mode, glasses split incoming 1920x1080 SBS to each eye
sbs_mode=disable    # 2D mode, both eyes see same 1920x1080
```

Other strings rejected with `Invalid sbs_mode value: %s` (rejects
`true`/`false`, `0`/`1`, `disabled`/`enabled` plural forms,
`stretched`). The exact valid values are `enable` / `disable`.

Closed-source `libRayNeoXRMiniSDK.so` exposes
`ffalcon::XRMiniService::SwitchTo2D()` / `SwitchTo3D()` which the
control IPC dispatches to.

xr-driver must be running for these to take effect.
`breezy-hyprland` stops xr-driver, so toggle BEFORE launching it.
xr-driver does NOT toggle the glasses back to 2D when stopped — the
glasses retain whatever mode was last set.

## Glasses content rendering: rainbow streaks pattern

When the present cycle DOES land frames on the glasses, the visual
output is "left half black, right half rainbow vertical streaks."
Two contributing factors (still being separated):

1. **Resolution mismatch**: monado wants 3840x1080 SBS; EDID only
   advertises 1920x1080; Mesa restricts surface to 1920x1080
   (`comp_window_direct_create_surface: Ignoring given extent
   3840x1080 and using 1920x1080 from mode`); glasses in 3D mode
   then split the 1920-wide signal into 960x1080 per eye instead
   of the expected 1920 per eye → distorted/garbled.
2. **Storage-only swapchain**: monado requests
   `VK_IMAGE_USAGE_STORAGE_BIT` only (no `COLOR_ATTACHMENT_BIT`,
   no `TRANSFER_DST_BIT`). Mesa likely allocates the image with a
   compute-shader-optimal tiling modifier. DRM `MODE_ADDFB2` (the
   modifier-less variant — no `MODE_ADDFB2_WITH_MODIFIERS` ioctl
   call observed) defaults the framebuffer to linear. Tiled memory
   scanned out as linear = vertical-streak rainbow pattern.

Phase 3.5 candidate fixes:
- Add a 3840x1080 DTD to the patched EDID so monado renders at
  native, glasses in 3D mode get the SBS signal they expect
- Patch monado's swapchain create to add `COLOR_ATTACHMENT_BIT` to
  usage flags
- Look at Mesa's `wsi_display_image_init` to see if it forces
  scanout-compatible modifier or trusts the requested usage flags

## STORAGE_BIT-only swapchain on Mesa anv → non-scanout tiling (2026-05-06)

`monado/comp_renderer.c:543-549` requests
`VK_IMAGE_USAGE_STORAGE_BIT` *without* `COLOR_ATTACHMENT_BIT` for the
WSI display swapchain when `use_compute=true` (default on Linux per
`comp_settings.c:13-17`). On Mesa anv (Intel Arc MTL), STORAGE-only
appears to push the image to a tiling/modifier that KMS display
planes can't address — compute shader fills the image, but the panel
shows black or garbage.

Evidence: v4 diagnostic with `XRT_COMPOSITOR_COMPUTE=0` (forces the
graphics path that already had `COLOR_ATTACHMENT_BIT`) reached
FOCUSED with no SURFACE_LOST and clean swapchain present. SEGV in
wayvr after that is a separate issue.

Patch lives at
`system/lib/xr/monado-rayneo/patches/comp-renderer-scanout-compatible-tiling.patch`
and pairs `COLOR_ATTACHMENT_BIT` with `STORAGE_BIT` on the compute
branch. Wired into `system/lib/xr/monado-rayneo/package.nix` patches
array. **NOT YET VERIFIED end-to-end with breezy-hyprland** — pending
test post-rebuild.

## Mesa wsi_display_debug is compile-time disabled (2026-05-06)

`MESA_VK_WSI_DEBUG=display` and `WSI_DEBUG=display` print **nothing**
for the KHR_display path because `wsi_display_debug` /
`wsi_display_debug_code` macros at
`mesa/src/vulkan/wsi/wsi_common_display.c:99-105` are wrapped in
`#if 0`. To get traces you'd have to flip the macro and rebuild Mesa.
See `memory/xr-mesa-wsi-debug-disabled.md`. Don't waste time
debugging env-var propagation when the macro is off.

## Offline OSS source corpus is high-leverage (2026-05-06)

The `.research/` clone-everything pattern (mesa, monado, kernel DRM,
Hyprland v0.54.3, wlroots, aquamarine, gamescope, wivrn, vulkan
loader/headers/validation, OpenXR, wayvr, ~1.8 GB total) was the
single highest-leverage tool for finding the
`comp_renderer.c:543-549` smoking gun. Grep against local checkouts
beats web fetches: faster, no rate limit, can `git log -p`, can
cross-reference between repos in one shell. Pattern documented in
`memory/xr-research-corpus.md`. Refresh by `git pull` in individual
src/ subdirs when upstream lands a relevant change.

## Last log line ≠ last function call (2026-05-06)

When a crash happens in unsafe FFI / Vulkan code, the relevant
signal is **what code path is entered next**, not what logged most
recently. We spent a fix-and-verify cycle on the wrong thing here:

- v4 breezy run: last two log lines were the wayvr "Using GPU
  capture" warning at `screen/backend.rs:200`, then wgui's
  `Grow Color atlas 256 → 512` at `text_atlas.rs:190`, then SEGV.
- The previous agent attributed the crash to atlas-grow (citing
  the racy `text_atlas::grow()` that swaps `image_view` without
  `queue.wait_idle()`), shipped a workaround in `b02dffa` raising
  the initial atlas from 256 → 2048 so growth never happens, and
  wired it as the `wayvr-anv` overlay.
- The patch worked at its stated job: the post-patch v3 log shows
  NO `Grow Color atlas` line. But wayvr **still segfaults at the
  same wall-clock distance from FOCUSED**, in the same place.

So the atlas log was the *previous log line*, not the *previous
function call*. The actual next step after the GPU capture warning
is `MyFirstDmaExporter::new(...)` and `self.capture.init(...)` two
lines below in `backend.rs:200-217` — DMA-BUF import into vulkano,
which never logs anything before it crashes natively.

Lesson: in unsafe code, treat "log line right before SEGV" as a
location estimate, not an attribution. Read the next 20 lines of
source after the last log call before assigning blame. If the
post-patch crash is identical to the pre-patch crash, the patch
fixed something that wasn't the bug.

## wayvr's GPU-capture warning lists the workaround inline (2026-05-06)

The warning text itself says how to fall back to CPU capture:

  "Using GPU capture. If you're having issues with screens, go to
  the Dashboard's Settings tab and switch 'Wayland capture method'
  to a CPU option!"

Useful when GPU capture crashes (it does on Mesa anv — see
`memory/xr-wayvr-gpu-capture-segfault.md`). Catch: we don't have
the dashboard rendering yet (the dashboard is the thing wayvr is
trying to open when it crashes). So the in-UI toggle is unreachable
right now. Look for:

- a config file under `~/.config/wlxoverlay/` or similar that
  persists `capture_method`
- an env var override (grep wayvr source for `capture_method` /
  `CaptureType` / `WAYVR_*`)
- a CLI flag on `wayvr --openxr ...`

Whichever exists is the cheapest path to "wayvr that doesn't
crash on lewis," and lets us verify the rest of the visual chain
(monado present cycle → glasses) end-to-end without first solving
the DMA-BUF import bug.

## CDCLK budget on Intel display engines bites at lease time (2026-05-06)

The lewis hardware (Intel Arc MTL) tolerates roughly **1.0 GP/s** of
total active-output pixel bandwidth. Adding the leased 3840x1080@60
DP-2 surface from the glasses on top of eDP-1@1920x1080@120 +
HDMI-A-1@1920x1080@119.98 sums to ~1.12 GP/s — over budget.

When wp_drm_lease_v1 fires and Hyprland reconfigures all outputs to
honour the lease, the atomic modeset fails and aquamarine logs

  drm: Cannot commit when a page-flip is awaiting

repeatedly until the watchdog kills Hyprland into safe-mode.
Smoking gun: `/run/user/1000/hypr/521ece...1778064687_*/hyprland.log`
lines 511-513.

Workaround landed in commit `1f84b02`: cap HDMI-A-1 at 60Hz in
`dotfiles/default/hypr/users/jorge/default/monitor.conf`. Total drops
to ~995 MP/s, under threshold, page-flip-loop stops. (Hyprland is
STILL crashing into safe-mode on plain login post-cap; root cause
of that is open — see `memory/xr-hyprland-cdclk-cap.md`.)

Real upstream fix would be Hyprland sequencing the lease handover so
non-leased outputs get downgraded *before* the lease modeset. Until
then, on Intel hosts running XR with a high-bandwidth lease target,
sum (W × H × refresh) for all active outputs and lower one if you're
near 1 GP/s. Reference: `memory/xr-hyprland-cdclk-cap.md`.

## fetchCargoVendor derivation name keys off pname (2026-05-06)

`fetchCargoVendor` (the modern replacement for `cargoSetupHook` /
`cargoFetchHook`) uses the package's `pname` as part of the vendor-
staging derivation's name. `overrideAttrs` that change `pname` —
e.g., renaming `wayvr` → `wayvr-anv` to mark a patched variant —
force a fresh download of the vendor staging. For Rust crates with
hundreds of transitive dependencies that download is 30+ minutes
per iteration of any patch tweak.

Lesson: when adding patches to a Rust derivation, **keep `pname`
stable**. Only the build phase needs to reinvalidate. Add patches
via `patches = (oldAttrs.patches or []) ++ [ ./foo.patch ]` without
touching `pname` and the cached vendor staging stays valid.

Applied in commit `5954b91` — dropped the `pname = "wayvr-anv"`
override on the vendor-staging derivation so future wayvr patch
iterations don't trigger a 30-min re-fetch every time. The wgui
atlas-grow patch from `b02dffa` is unaffected (the vendor staging
just rebuilds the build outputs).

## Two distinct Hyprland safe-mode mechanisms (2026-05-06 round 2)

"Hyprland is in safe-mode again" is not a single failure — at least
two different mechanisms with different log signatures and different
fixes have hit on `lewis` in the same week:

**(a) CDCLK-overrun page-flip-awaiting loop.** Dead log
`/run/user/1000/hypr/521ece...1778072203_*/hyprland.log` lines
5411-5585 show repeated `drm: Cannot commit when a page-flip is
awaiting` entries while external HDMI-A-1 was plugged. Reproducible
when eDP-1 + external + leased DP-2 push past the Intel display
engine's ~1 GP/s CDCLK ceiling. Mitigated by commit `1f84b02`
(HDMI-A-1 capped to 60Hz). Companion file:
`memory/xr-hyprland-cdclk-cap.md`.

**(b) Event-loop stall during DP-2 hot-plug.** Same dead log,
lines 16182-16216, fired at 22:41:09 — but external was unplugged at
crash time (per line 9415 onward), bandwidth ~870 MP/s, under CDCLK
ceiling. Watchdog SIGABRT'd Hyprland mid-`SDRMConnector::connect()`
mode iteration. Internal aquamarine data-setup, NOT a kernel modeset.
Leading hypothesis (unconfirmed): EDID-blob I2C read at
`.research/src/aquamarine/src/backend/drm/DRM.cpp:1726` blocking, or
DRM-fd ioctl contention with monado's concurrent lease ops.
Mitigated by nothing yet. Companion file:
`memory/xr-hyprland-lease-hotplug-stall.md`.

**Lesson:** never assume a single root cause when "safe-mode again"
shows up. Different log signatures, different fixes. Specifically,
check whether the external monitor was actually plugged at *crash
time* (not just earlier in the session) and sum active-output
bandwidth at crash time before attributing to CDCLK. The 1f84b02 cap
only addresses (a); (b) is independent and currently unmitigated.

## non_desktop is being detected correctly on this stack (2026-05-06)

When investigating Hyprland-DP-2 issues, **don't re-blame the EDID
override or the `non_desktop` bit.** Aquamarine logs `drm: Non-desktop
connector` 4 times in the 2026-05-06 session sig 1778072203
(hyprland.log lines 1984, 2549, 3041, plus one more), and wp-drm-lease
was granted at lines 2580-2583 (`drm lease: output DP-2 ... lease
granted with lessee id 2`). The kernel + EDID override + aquamarine
non_desktop detection are all working as intended. Failures in the
glasses pipeline at this point are not coming from a missed
non_desktop bit.

## Coincident log line ≠ root cause, second time (2026-05-06)

This is the second time we've blamed the wrong thing for the wayvr
segfault based on which line was last in the log:

1. **First time:** atlas-grow (`Grow Color atlas 256 → 512`) was
   the previous log line; we shipped a patch raising the initial
   atlas to 2048 (`b02dffa`). The patch worked at its job (no more
   atlas-grow log) but wayvr segfaulted at the same wall-clock
   distance from FOCUSED. Documented in the existing
   "Last log line ≠ last function call" entry.
2. **Second time (this round):** with the atlas-grow log gone,
   the `Using GPU capture` warning at `screen/backend.rs:200` looked
   like the next obvious culprit (DMA-BUF import into vulkano
   immediately follows). We dropped a `capture_method: screencopy`
   override at `~/.config/wayvr/config.yaml`. Confirmed by log
   (`Not using DMA-buf capture due to ScreenCopyCpu`) followed by
   `Software capture will take place on the main thread`. SEGV one
   line later. So DMA-BUF was *also* coincident. The actual crash
   sits in the post-method-decision / capture-init region —
   probably Vulkan queue setup or a vulkano-anv interaction that
   logs nothing before crashing.

Pattern: wayvr/vulkano on Mesa anv has a sequencing bug where the
crash happens shortly after a logged operation, and the operation
that logs is not the operation that crashes. **Stop blaming the
last log line. Get a backtrace.** Either `coredumpctl info wayvr`
post-segfault or `gdb --args wayvr --openxr --show` with `bt full`
in the crashing frame. Until that's done, every new "obvious next
suspect" is going to be wrong.

## EBUSY on atomic_commit means CRTC contention (or transient flip), not surface-lost (2026-05-07)

When investigating `VK_ERROR_SURFACE_LOST_KHR` in Vulkan WSI direct-
display on Mesa, the actual kernel errno can be one of several
(`EBUSY`, `EINVAL`, `ENOSPC`, `EIO`, …). Mesa's
`wsi_common_display.c:3122-3134` translates **any non-`EACCES`
atomic_commit failure** to a single `VK_ERROR_SURFACE_LOST_KHR`. The
original errno is dropped on the floor. `wsi_display_debug` could log
it but is `#if 0`'d at compile time (see
`memory/xr-mesa-wsi-debug-disabled.md`).

**Strace is the only way to see the real errno without rebuilding
Mesa.** Run monado-service under `strace -f -e trace=ioctl
-o .scratch/.../strace.log` and grep
`DRM_IOCTL_MODE_ATOMIC.*= -1 E`. The line right before the
`VK_ERROR_SURFACE_LOST_KHR` write is the one that matters.

In the 2026-05-07 v2 strace on `lewis` the errno was `EBUSY`. EBUSY
in this context means "another DRM client is holding state you tried
to commit" — i.e. CRTC, plane, or connector contention, possibly
transient (a page-flip in flight) or persistent (someone else owns
the resource). It is **not** "surface destroyed by the system". A
caller that retries on the proper errno would likely succeed; monado
doesn't, because it sees `VK_ERROR_SURFACE_LOST_KHR` and
`comp_renderer.c renderer_present_swapchain_image` has no retry path
for that. See `memory/xr-mesa-anv-ebusy-on-first-present.md` for the
canonical writeup.

Lesson: when SURFACE_LOST shows up in a Mesa WSI display path, treat
the Vulkan error code as "something failed in `wsi_common_display.c`,
unknown errno". Don't reason about it as "surface lost"
semantically — Mesa just used the closest available enum. Strace
first.
