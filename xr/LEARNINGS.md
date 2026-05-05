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
