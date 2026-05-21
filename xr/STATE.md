# XR system state

Last updated: 2026-05-21 (post BIOS 301→311 flash attempt)

## 2026-05-21 — BIOS 311 flash attempted, EC altmode wedge UNCHANGED

After ~1-2 weeks of non-XR usage, Jorge returned wanting "just use the
glasses as a basic display, no head-tracking". DP altmode was still
wedged with the same fingerprint as 2026-05-09 (accessory_mode=none,
no altmode subdir, EDID 0 bytes despite firmware-override status=connected).

We escalated to the BIOS flash that was the recommended next step in
`memory/xr-lewis-ec-refuses-altmode.md`:

- **Procedure note**: ASUS Zenbook UX3405MA does NOT have a `Tool` tab
  (motherboard-only per ASUS FAQ 1054166). The local USB flash utility
  is called **"ASUS Firmware Update"** (not EZ Flash), under no
  specific tab. Inside it, choose **"via Storage Device(s)"** (local)
  not "via Internet" (cloud). Stick must be in **USB-A port** (Meteor
  Lake Zenbooks have a pre-boot USB-C enumeration quirk). New
  reference memory: `memory/asus-zenbook-bios-flash-quirks.md`.
- **Flash succeeded cleanly**: `cat /sys/class/dmi/id/bios_version` →
  `UX3405MA.311`, date `06/06/2025`.
- **Result on first plug post-flash**: identical wedge fingerprint.
  `port1-partner/accessory_mode=none`, `number_of_alternate_modes=0`,
  no `port1-partner.0/` altmode subdir, `card1-DP-2/edid=0 bytes`.
  Kernel journal on plug shows ONLY USB HID enumeration — zero
  typec/UCSI/DP events. Same dead silence as before.

**Implication.** The "BIOS reflash is the documented recovery path"
hypothesis (Slimbook EVO15-A8 precedent) is **provisionally falsified
for this exact bug on this hardware**. Either UX3405MA.311's EC blob
doesn't differ in altmode policy from .301, the lockout lives in a
flash region the BIOS capsule doesn't reach, or recovery needs a
specific post-flash sequence not yet tried. See
`memory/xr-lewis-ec-refuses-altmode.md` 2026-05-21 section for full
detail and remaining cheap probes (suspend-replug timing, other
USB-C port, cable orientation, TBT4-certified cable, Live USB Fedora
diagnostic).

Phase 4 visual verification and Phase 3.10 remain BLOCKED. xr-driver
sideview mode is still usable (USB+HID only, no DP altmode required).

## 2026-05-08 morning session — DP altmode firmware wedge diagnosed

What is currently deployed on `lewis` (and wired for `verse`), what is
verified working, and what is broken or deferred. Update this whenever
the deployed state changes (new module wired in, new contract changed,
new known-broken thing).

## Hosts in scope

| Host | User | Status |
|---|---|---|
| `lewis` | `jorge` | xr-driver + breezy-gnome + breezy-session + breezy-recenter + **monado-rayneo (patched: comp-renderer pairs COLOR_ATTACHMENT_BIT with STORAGE_BIT, `3bf13da` VERIFIED on monado side) + breezy-hyprland (with wayvr-anv override) + glasses-edid (EDID override + 3840x1080 mode injection + USB ACL fix)** deployed. Currently running the rolled-back gen `549bd84` (built 2026-05-05). GNOME-Breezy soak abandoned. **Phase 3 progress:** (1) launcher socket race FIXED commit `f74154b`; (2) EDID injects 3840x1080@60 DTD (`7122089`); (3) monado swapchain usage-flag patch `3bf13da` verified active in current build (swapchain log shows `imageUsage: STORAGE_BIT + COLOR_ATTACHMENT_BIT`, `imageExtent: {3840, 1080}`). User-facing "see something on the glasses" still blocked by the issues below. **Open issues:** (a) **SURFACE_LOST root cause located (Round 3, 2026-05-07):** strace v2 caught the kernel errno hidden behind the SURFACE_LOST — `DRM_IOCTL_MODE_ATOMIC` returns `-1 EBUSY` on the first present commit, and Mesa's `wsi_common_display.c:3129` flattens any non-EACCES atomic_commit failure to `VK_ERROR_SURFACE_LOST_KHR`. Monado has no retry on SURFACE_LOST. Leading hypothesis (unconfirmed): CRTC contention with Hyprland's stale aquamarine CRTC binding on DP-2. See `memory/xr-mesa-anv-ebusy-on-first-present.md` (canonical) and `memory/xr-mesa-anv-display-gap.md` Round 3 for next steps. Strace at `.scratch/wayvr-trace/strace-monado-20260507-002455.log.<tid>`. (b) **wayvr capture-init crash on Mesa anv (timing-dependent):** coredump backtrace localized the crash to `WCommandBuffer::upload_image` `copy_from_slice` (memory/xr-wayvr-gpu-capture-segfault.md) — leading hypothesis is unchecked `mmap` in `receive_callback` MemFd path. **Not always-reproducing:** the 200645 run with glasses-already-connected did NOT crash wayvr; it ran for many minutes until Jorge Ctrl+C'd. May correlate with hot-plug-mid-init rather than generic startup. (c) **Hyprland safe-mode — two distinct mechanisms:** the `1f84b02` HDMI@60 cap remains correct for the CDCLK-overrun mode (real, reproducible per dead log lines 5411-5585 when external is plugged) — see `memory/xr-hyprland-cdclk-cap.md`. **A separate event-loop-stall safe-mode mode** was identified in the 2026-05-06 22:41 crash: external was unplugged at crash time (~870 MP/s, under CDCLK ceiling), Hyprland watchdog SIGABRT'd during aquamarine `SDRMConnector::connect()` mode iteration on DP-2 hot-plug. See `memory/xr-hyprland-lease-hotplug-stall.md`. (d) **Latest gen built 2026-05-06 gray-screens on boot:** Jorge built a "latest" gen today that gray-screens; rolled back to `549bd84`. Root cause unknown, not investigated this session. (e) **TODO — codify the wayvr CPU-capture workaround into dotfiles:** `~/.config/wayvr/config.yaml` is currently out-of-tree (dropped for fast iteration). Once a real fix exists, move the desired config into `dotfiles/default/wayvr/config.yaml` so the dotfile-symlink activation script deploys it. (f) **Minor:** stale `/run/user/1000/monado_comp_ipc` socket can persist after an unclean monado exit; the launcher's `f74154b` cleanup only runs on launcher startup, not on un-clean exit. Next launch handles it; not urgent. (g) **2026-05-08 — DP altmode RE-WEDGED post-reboot; three-agent dungeon located lockout in EC firmware flash.** Yesterday's "recovery" was transient. Today's rebooted state has the same UCSI fingerprint (`GET_CAM_SUPPORTED=0`, partner advertises DP SVID `0xff01`, `SET_NEW_CAM` times out). Replug, port swap, orientation flip, and ASUS-documented 40s+AC EC reset (FAQ 1050239) all NO-OP. Three parallel sub-agent dive: (i) full DSDT + 21 SSDTs dumped + searched — zero ACPI methods reset/clear UCSI policy state; (ii) EC RAM regions are kernel-writable but the EC PPM ignores `SET_NEW_CAM` writes — the policy decision is in EC firmware flash, not RAM; (iii) [SLIMBOOK EVO15-A8 (March 2026 gist)](https://gist.github.com/gnespolino/81abd597153fd19aa2a039f66b8359a3) reproduced an identical fingerprint across multiple distros via live USB and recovered ONLY via EC firmware reflash; (iv) kernel-side fix already present (Berg 217504a055 in 5.10+, every NixOS kernel has it; `linuxPackages_latest`/`_zen`/`_xanmod_latest` all 7.0.x). **Diagnosis**: lockout state lives in EC firmware flash (SPI/OTP), unreachable from any userspace path. **Recovery candidates ordered by cost**: (1) suspend → wait for `-70` UCSI errors in dmesg → fresh replug — cheap untested timing per `memory/xr-ec-altmode-suspend-replug-untested.md`; (2) plug glasses during BIOS POST, sit 30-60s, then boot; (3) Live USB Fedora 42 (kernel 6.12.x) — diagnostic only; (4) BIOS UX3405MA.301→311 (`.scratch/bios-311/UX3405MAAS.311` already downloaded + verified) — strongest evidence per Slimbook precedent. Phase 3.10 visual verification still BLOCKED. (h) **Phase 4 SOFTWARE-LAYER VERIFIED.** breezy-hyprland launcher (`212a6f0`) spawns 4 headless wl_outputs (HEADLESS-2..5), workspaces 2-5 mapped, ScreenCopy capture active for each, monado leases DP-1/DP-2, IPD=63 read from device, OpenXR FOCUSED reached, curved-arc patch (`4b10b72`) builds + runs. Cleanup teardown leaves system identical to pre-launch. EDID firmware override broadened to DP-1+DP-2 (`96dd306`). Visual verification still blocked by issue (g) above — panel pure black until altmode recovers. |
| `verse` | `eksno` | Same module set wired (xr/driver, xr/breezy-gnome, xr/breezy-session, xr/monado-rayneo, xr/breezy-hyprland). Build verified; not yet exercised on real hardware. |

## 2026-05-08 morning session — DP altmode firmware wedge diagnosed

Phase 3.10 verification got hard-blocked when DP altmode stopped
entering on lewis after the heavy plug/unplug cycling on 2026-05-07.
The morning was spent narrowing down the cause:

- **What worked at 14:12 on 2026-05-07** (Hyprland aquamarine log
  proves it): SmartGlasses connected on DP-1 with EDID, monado
  successfully leased it via `wp-drm-lease-v1`, OpenXR FOCUSED.
  Same NixOS gen `549bd84`, same kernel 7.0.3, same BIOS, same cable,
  same glasses.

- **What didn't recover it across the day and morning**: cable
  orientation flip, USB-C port swap (top vs bottom), 5-min
  glasses-unplugged for cap discharge, `ucsi_acpi` driver
  unbind/rebind on `USBC000:00`, xhci PCI driver unbind/rebind
  on `0000:00:14.0`, `usbcore.autosuspend=-1` runtime tweak,
  `systemctl suspend` + wake, `sudo reboot`, full cold cycle
  (shutdown + AC unplug + 30s power button hold), UCSI
  `CONNECTOR_RESET` (0x03) via debugfs, UCSI `SET_NEW_CAM` (0x0f) to
  force-enter DP altmode (times out), UCSI `PPM_RESET` (0x01)
  ("Operation not supported"), connecting glasses with no charger.

- **The fingerprint** (proven via raw UCSI debugfs at
  `/sys/kernel/debug/usb/ucsi/USBC000:00/{command,response}`):

  | UCSI command | Result | Implication |
  |---|---|---|
  | `GET_CAPABILITY` (0x06) | `features = 0x0000` | No `ALT_MODE_DETAILS` capability bit |
  | `GET_CONNECTOR_STATUS` (0x12) | byte 2 includes `partner_flags=2` | EC SEES partner is altmode capable |
  | `GET_ALTERNATE_MODES` (0x0c) | `0x...0405ff01` | Partner advertises DP SVID `0xff01` (correct) |
  | `GET_CAM_SUPPORTED` (0x0d) | `0x0000...` | EC won't expose any CAM for the port |
  | `SET_NEW_CAM` (0x0f) | timeout | EC actively refuses altmode entry |

  The EC has the partner data but its policy refuses to register a
  CAM. Function trace of `ucsi_*` confirms the kernel never calls
  `ucsi_register_altmodes` because `ucsi_handle_connector_change`
  only invokes it when `change & UCSI_CONSTAT_CAM_CHANGE` (bit 10)
  is set, and bit 10 is never set in any of the connect events
  (observed `change=0x4800, 0x5800, 0x0a00`).

- **The "why now and not before" answer** (honest version): we don't
  know what specifically transitioned the EC's altmode policy from
  "register CAMs" → "refuse CAMs" between 14:12 and 14:30 on
  2026-05-07. Most plausible: a specific sequence during the heavy
  cycling we were doing (some combination of monado-leasing,
  Hyprland-watchdog-killing-aquamarine-mid-altmode-active,
  SIGKILL-on-monado-stranding-USB-claim, etc.) wrote a "lockout"
  state to the EC's NVRAM region. Cold cycle wipes RAM but not
  NVRAM, which is why even shutdown + 30s power button hold
  doesn't recover.

- **Sudoers timestamp_timeout extended to 60min**:
  `system/lib/power-mode/default.nix:1040-1042` — single
  `sudo -v` now primes credentials across all of jorge's shells
  (including Claude Code Bash tool calls) for an hour. Saves
  password prompts during debug sessions involving lots of sudo
  (kernel tracing, sysfs writes). `!tty_tickets` makes the sudo
  ticket cache shared across ttys instead of per-tty.

- **Memory entry**: `memory/xr-lewis-ec-refuses-altmode.md` has the
  5-command UCSI recipe so future-Claude can fingerprint this
  failure mode in 30 seconds without re-deriving it. Index entry
  added to `memory/MEMORY.md`. Older
  `memory/xr-lewis-altmode-discovery-stuck.md` (which claimed cold
  cycle is the fix) is now superseded but retained for narrative
  trail.

### What's not blocked

- **xr-driver / IMU / mouse mode** — works fine over plain USB+HID.
  Pose data still flows; sideview is fully usable. Phase 3.10's
  "see something on the glasses panel" goal is what's blocked.
- **Software changes that don't need real hardware** — Phase 3.7
  monado retry patch can still be polished/reviewed; Phase 4
  (N-screen layout) design work; Phase 3.8 (Mesa errno translation)
  if we choose to revive it.

### Recovery options tested

1. **F2 at POST → F9 (Restore Defaults) → F10 (Save & Exit)** —
   ❌ **VERIFIED INEFFECTIVE 2026-05-08**: post-reset UCSI fingerprint
   identical to pre-reset (`GET_CAM_SUPPORTED=0`, `accessory_mode=none`,
   no svid). Only attribute byte changed by 1 bit (`0x4146 → 0x4046`).
   Side effect: re-enabled secure boot → NixOS skipped, fell through
   to Ubuntu fallback; Jorge disabled secure boot to recover. The EC's
   altmode policy state is NOT in the NVRAM region BIOS Restore
   Defaults clears.
2. **Long idle wait** — UNTESTED. Some EC firmware bugs self-clear
   after hours/days of no USB-C activity. Re-test periodically with
   the 5-command UCSI recipe in
   `memory/xr-lewis-ec-refuses-altmode.md`.
3. **TBT4-certified cable** — UNTESTED. Rules out cable-specific
   firmware quirk. Cable works on phone but lewis's TBT4 controller
   is stricter.
4. **BIOS firmware flash** — UNTESTED. Latest BIOS for UX3405MA at
   https://www.asus.com/laptops/for-home/zenbook/asus-zenbook-14-oled-ux3405ma/helpdesk_bios/.
   Flashing newer BIOS almost always clears EC NVRAM as a side
   effect, regardless of code changes.
5. **Battery-disconnect pinhole** — UNTESTED. If this Zenbook model
   has one (some do). Most aggressive non-flash reset.
6. **Boot without aggressive power-saving kernel params** — UNTESTED.
   `system/lib/device/intel/default.nix` sets `i915.enable_dc=4`,
   `pcie_aspm=force`, `acpi.ec_no_wakeup=1`, `usbcore.autosuspend=1`.
   These were active when the wedge first triggered. Worth a one-off
   reboot with them removed to see if the EC behaves differently.

### Other things proven INEFFECTIVE in the same diagnostic session

UCSI runtime resets that all returned no-change: `CONNECTOR_RESET`
soft (0x03 con=1), `CONNECTOR_RESET` hard (0x03 with bit 23 set).
Kernel-blocked: `PPM_RESET` (0x01), `SET_NOTIFICATION_ENABLE` (0x05),
`SET_NEW_CAM` (0x0f) all return "Operation not supported" or time out
when issued via `/sys/kernel/debug/usb/ucsi/USBC000:00/command`.

## 2026-05-07 evening session — Phase 3.5 progress

The Phase 3.5 plan at `~/.claude/plans/mossy-chasing-cray.md` was
approved this evening. Two of the three workstreams progressed; one
deferred.

- **Workstream 1 (CRTC diagnostic) — DONE.** An `LD_PRELOAD` shim
  (`crtc-trace.c` / `build-crtc-trace.sh`, both gitignored under
  `.scratch/wayvr-trace/`) was built. Run `20260507-012348` shows
  monado IS targeting CRTC 267 (the same one aquamarine binds to DP-2)
  → the geometric premise of the CRTC-contention hypothesis is
  confirmed. **However**, that same run captured 4466 successive
  `DRM_IOCTL_MODE_ATOMIC` successes with zero EBUSY and presented
  47670 frames at ~30 fps. Round 3's EBUSY is therefore **intermittent**,
  not a guaranteed failure on every cold boot. Possible reason: the
  shim's per-atomic ~10–20 sync `DRM_IOCTL_MODE_GETPROPERTY` ioctls
  add ~1–2 ms of latency that incidentally breaks the timing race.
  See `memory/xr-mesa-anv-ebusy-on-first-present.md` "Intermittent —
  not always-reproducing" section.

- **Workstream 2 (monado SURFACE_LOST retry) — AUTHORED + COMMITTED,
  not yet built/tested.** Three commits (`baa7b4e`, `d4865e4`,
  `6265f3c`) add a bounded retry around
  `renderer_present_swapchain_image` so a transient first-present
  EBUSY (which Mesa flattens to SURFACE_LOST) doesn't permanently
  kill the present cycle. Defense-in-depth — still defensible even
  with EBUSY proven intermittent. FIXES.md has the entry. **Pending:**
  `./update-without-update.sh && hyprctl reload` then re-run to
  confirm the retry path actually executes when EBUSY ever fires
  again, and that no regressions slip in.

- **Workstream 3 (Mesa errno translation EBUSY → VK_NOT_READY) —
  DEFERRED.** Lower priority now that EBUSY is intermittent and
  monado has a retry path. Revisit if EBUSY shows up frequently in
  real workloads.

### Operational findings

- **Glasses panel transitioned BLACK → DARK.** Earlier in the day the
  panel was completely off (DPMS off / no signal). Tonight it shows a
  dark-but-on screen — scanout is happening. Three competing sub-
  hypotheses, none verified yet: (a) wayvr's default OpenXR composition
  layer is intentionally dark (no apps streaming), (b) firmware-default
  brightness is low because xr-driver (which normally bumps it) is
  masked, (c) `VK_FORMAT_A2B10G10R10_UNORM_PACK32` 10-bit content into
  an 8-bit panel truncates top 2 bits → ~25% brightness range. Pending
  visual ground truth from Jorge.

- **xr-driver coordination friction.** `systemctl --user stop
  xr-driver` is racy because the unit auto-restarts and re-claims the
  USB device, beating monado's 30-retry libusb_open window. Workaround:
  `systemctl --user mask xr-driver` for the run; `unmask` after. Wired
  into `.scratch/wayvr-trace/run-strace-v2.sh`. See
  `memory/xr-usb-driver-coordination.md`.

- **Rayneo USB topology clarified.** Glasses are libusb at
  `/dev/bus/usb/003/003` (mode `root:users 660`), NOT hidraw. The
  two `/dev/hidraw*` on lewis are Intel ISH + I2C touchpad. Monado's
  `rayneo_usb.c` uses `USBDEVFS_DISCONNECT_CLAIM` /
  `USBDEVFS_SUBMITURB`. See `memory/xr-rayneo-libusb-not-hidraw.md`.

- **SIGKILL on monado strands the USB claim.** The kernel keeps the
  `USBDEVFS_DISCONNECT_CLAIM` record for the dead PID, so subsequent
  `libusb_open` fails until the device is rebound. Soft-reset via
  `echo 3-2 > /sys/bus/usb/drivers/usb/{unbind,bind}` recovers without
  unplugging. See `memory/xr-monado-sigkill-usb-stuck.md`.

- **monado RAYNEO_* logs default to INFO.** Critical init lines like
  `Switching to 3D mode...` and `3D mode confirmed` are DEBUG-only and
  invisible in default logs (`rayneo_hmd.c:45-48,495,506`). Set
  `XRT_LOG=debug` to see them — wired into the v2 runner. See
  `memory/xr-monado-debug-log-level.md`.

- **v2 runner truncate hazard.** `> $MONADO_LOG` plus an orphan monado
  fd makes the log sparse → ripgrep "binary file matches" with NUL
  bytes. Always confirm `pgrep -af monado-service` empty before
  re-running. See `memory/xr-v2-runner-sparse-log.md`.

- **wayvr UTC vs system UTC+7.** A wayvr line dated `2026-05-06T19:13Z`
  is actually `2026-05-07T02:13` local. Don't flag as stale. See
  `memory/xr-wayvr-utc-timestamps.md`.

### Outstanding for next session

1. Visual ground truth on the dark screen (uniform vs gradient vs
   motion-tracked content) — shapes which sub-hypothesis to chase.
2. Confirm `SwitchTo3D` ACK by grepping this run's monado log (with
   `XRT_LOG=debug` active) for `Switching to 3D mode...` /
   `3D mode confirmed` / `3D mode switch timeout`, starting from the
   second `The Monado service has started` line.
3. Build + re-verify the monado retry patch (`baa7b4e` etc.) on real
   hardware.
4. Brightness control investigation if (1) shows tracked-but-dim content.

## What's deployed

### `xr-driver` (working)

- **Package**: `system/lib/xr/driver/{package.nix,default.nix}`. XRLinuxDriver
  v2.9.4. Includes patched udev rules (Rayneo hidraw subsystem match,
  uinput uaccess) and a stubbed `imu_protocol_xreal_one` so we can drop the
  XREAL One Rust subdriver without breaking link.
- **Runtime config**: `dotfiles/default/xr_driver/config.ini`. Four lines:
  ```
  disabled=false
  output_mode=external_only
  external_mode=breezy_desktop
  use_roll_axis=true
  ```
  `external_mode=breezy_desktop` is what enables the SHM IPC writer;
  `output_mode=external_only` alone is not enough. `use_roll_axis=true`
  feeds head roll into the pose stream (defaults differ by upstream
  build; explicit here for reproducibility).
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
