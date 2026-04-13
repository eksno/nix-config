# Fix Monitor Configuration

Diagnose and fix Hyprland monitor issues (mirroring, resolution, layout) for the current host/user.

## Process

### 1. Check source order

`hypr.sh` builds `hyprland.conf` as:
```
source = ~/.config/hypr/users/$USER/default.conf   # sourced FIRST
source = ~/.config/hypr/hosts/$HOSTNAME/default.conf  # sourced SECOND (wins)
```

**Host config always overrides user config.** If both define the same monitor, the host one wins.

### 2. Locate all monitor configs

- User-level: `dotfiles/default/hypr/users/$USER/default/monitor.conf`
- Host-level: `dotfiles/default/hypr/hosts/$HOSTNAME/default/monitor.conf`

Check both files for conflicts. If the host defines monitors that the user config already handles, clear the host-level monitor definitions and add a comment pointing to the user config.

### 3. Verify correct mirror syntax

Hyprland mirror syntax requires the full form:
```
monitor=eDP-1, <resolution>, <position>, <scale>, mirror, <MONITOR_NAME>
```

The short form `monitor=eDP-1, mirror, MONITOR_NAME` is **invalid** — `mirror` gets parsed as the resolution.

### 4. Verify supported resolutions

Run `hyprctl monitors all` and check the `availableModes` list for each monitor. Use only resolutions listed there. For the external monitor, prefer the highest supported refresh at native resolution (e.g. `1920x1080@100`).

### 5. Standard mirror config pattern

With HDMI-A-1 as primary and eDP-1 (laptop) mirroring it:

```
# users/jorge/default/monitor.conf
monitor=,preferred,auto,1                              # fallback
monitor=eDP-1, 2880x1800@120, 0x0, 1.25, mirror, HDMI-A-1
monitor=HDMI-A-1, 1920x1080@100, 0x0, 1

# hosts/lewis/default/monitor.conf
# Monitor config managed in users/jorge/default/monitor.conf
```

### 6. Apply and verify

```bash
hyprctl reload          # or ./hypr.sh
hyprctl monitors        # confirm mirrorOf and resolutions
```
