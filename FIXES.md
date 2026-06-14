# Fixes Log

Chronological log of non-trivial fixes for this NixOS flake. Newest entries at the top. See `CLAUDE.md` "Log Every Fix" section for the entry format and rules.

**Before debugging a new issue, grep this file first** — a past investigation may contain the answer.

## 2026-06-14 — corne-keyless-trusted-bond-desync-recurring (self-healing)

**Symptom:** Mako buried under ~19 stacked "Corne / Connected" + "Corne / Disconnected" notifications (blueman-applet), "(14 more)". Keyboard not usable.
**Affected:** host `verse`, user `eksno`. Corne `C8:5B:C1:B5:9B:F3`, host adapter `2C:33:58:44:27:4D`. Not a repo-file bug — host BlueZ bond state + ZMK firmware in `~/repos/eksno/zmk-dvorak-36`.
**Root cause:** The host held the Corne as `Trusted=yes` but with **zero bond keys** — `/var/lib/bluetooth/2C:33:58:44:27:4D/C8:5B:C1:B5:9B:F3/info` contained only `[General]` (no `[PeripheralLongTermKey]`/`[SlaveLongTermKey]`/`[DeviceID]`), so `bluetoothctl info` showed `Paired: no / Bonded: no / Trusted: yes`. Because it was Trusted, BlueZ auto-connected on every advertisement, but with no LTK the link was unencrypted, so HID-over-GATT reads (PnP ID, HID Information, Report Reference) failed with ATT 0x0E "Request attribute has encountered an unlikely error" → HoG never attached → drop → retry every ~30s, blueman firing a notification per transition. **CORRECTION (root cause):** an initial guess blamed ZMK firmware flashing, but the user confirmed they had **never reflashed** — this is a *spontaneous* ZMK↔BlueZ LE bond-key desync that recurs roughly every 2-3 days with no user action. The precise trigger is not definitively known and there is **no reliable Linux-side prevention** documented: ZMK's connection-issues page has zero Linux guidance, the community remedy is always a manual remove + re-pair, and `CONFIG_ZMK_BLE_EXPERIMENTAL_CONN=y` (set in `config/corne.conf`) is a suspect but is reportedly *needed* just to connect a split to Linux (zmk#2170/#1487) — removing it risks breaking connection, with 2-3 day feedback per attempt. This is NOT the 2026-05-22/05-23 autosuspend cause either: `power/control=on` was correctly applied to the BT controller this time.
**Investigation:**
1. Image looked like waybar but `bluetooth.sh` builds a fresh per-poll snapshot and never emits the word "Disconnected" → ruled out waybar; `makoctl history` + `app-name` showed the source was **blueman**.
2. `bluetoothctl devices` listed only ONE Corne, not 19 → the stack was accumulated event notifications, not duplicate devices.
3. `bluetoothctl info` → `Trusted: yes` but `Paired: no / Bonded: no`, RSSI -64 (in range). `sudo grep '^\[' .../info` → `[General]` only, vs a healthy device's `[General][DeviceID][LinkKey]` — the definitive keyless-bond proof.
4. 12s live `journalctl -f` caught zero Corne events (only unrelated "Auto-switch power profile" spam) — not actively flapping at that moment; the loop fires only when the keyboard advertises.
5. Dead end: first re-pair attempt via a bash `coproc` fed `pair` but produced empty output and left the device `Connected: yes / Paired: no` — an unencrypted connect that immediately hit the 0x0E loop again. The coproc didn't hold the SMP session reliably.
**Fix:** One-time recovery (no repo change). `bluetoothctl remove C8:5B:C1:B5:9B:F3` to drop the keyless Trusted entry, `sudo systemctl restart bluetooth` to clear stuck Adv-Monitor churn, then re-pair with the bluetoothctl session genuinely held open via a FIFO (write-end kept open with `exec 3>`, not a piped heredoc that EOFs mid-pairing). On the keyboard side, `&bt BT_CLR` (num layer, `config/corne.keymap:139`) clears the keyboard's profile bond so it re-advertises as pairable. Result: `Paired/Bonded/Trusted/Connected: yes`, `info` now has `[PeripheralLongTermKey][SlaveLongTermKey][DeviceID]`, `Corne Keyboard` input device attached, battery 100%. The host-side `remove` + held-open re-pair was sufficient (the keyboard was already advertising bond-less); `&bt BT_CLR` on the keyboard is only needed as a fallback if it isn't.
**Long-term (since prevention isn't reliable, make recovery free):** added `system/hosts/verse/corne-bt-recovery.nix` (commit `c048d1f`) — `corne-watch.service` tails the bluetooth journal for the `read_pnpid_cb` desync signature (debounced 2-in-120s) and auto-runs `corne-recover.service`, a host-side remove + FIFO-held re-pair (tries without a bluetoothd restart first, then with), with semantic notifications (detect/recover/fail) and a persistent tally at `/var/lib/corne-bt/events.log`. `corne-fix` triggers it manually. This collapses the ~30-min manual fix into a few hands-free seconds; the events log lets a future investigation measure frequency/patterns. The one-off recovery script used this session is at `.scratch/corne-repair.sh`.
**Commit:** `8213292`

## 2026-06-04 — waybar-bluetooth-module-blank-set-e-pipefail

**Symptom:** waybar's bluetooth module shows nothing even while a Bluetooth device (Corne keyboard) is actively connected and in use.
**Affected:** host `verse`, user `eksno`. `dotfiles/default/waybar/scripts/bluetooth.sh:7`, `dotfiles/default/waybar/config:68` (`custom/bluetooth`).
**Root cause:** The script ran `set -euo pipefail`. The battery line `battery=$(busctl … org.bluez.Battery1 Percentage 2>/dev/null | awk …)` exits non-zero (propagated by `pipefail`) whenever the connected device doesn't expose a `Battery1` interface. At boot the Corne connects before its BLE battery service is exposed (same late-service timing as the reconnect-loop fixes), so the script hit that line, `set -e` killed it, and `custom/bluetooth` had no `interval`/`restart-interval` — so waybar never respawned it and the module stayed blank for the whole session. The same fragility also crashes the script when zero devices are paired (`grep` exits 1 → pipefail → exit).
**Investigation:**
1. Ran `bluetooth.sh` by hand → emitted correct JSON (`Cor 44%`). So script *logic* was fine; bug was runtime.
2. `pgrep -af waybar` → waybar (PID 2710) alive with `network.sh` and `battery.sh` children running, but **no `bluetooth.sh` child** → the bluetooth exec had exited and was never restarted.
3. `busctl … dev_80…E7… org.bluez.Battery1 Percentage` → exit 1 (no Battery1 iface). Reproduced the crash: `bash -c 'set -euo pipefail; battery=$(busctl … Battery1 … | awk …)'` → exit 1, never reached the next line. Confirmed root cause.
4. Dead end ruled out early: suspected stale/non-symlinked `~/.config/waybar` (an `ls -la` showed regular files), but `readlink` confirmed it *is* a symlink to the repo and `diff` showed the config identical — not config drift.
**Fix:** `bluetooth.sh:7` `set -euo pipefail` → `set -uo pipefail` (drop `-e`; it's a resilient poll loop where optional-interface queries legitimately fail). Added `"restart-interval": 5` to `custom/bluetooth` in `config` as a respawn safety-net. Dotfiles are symlinked so changes were live immediately; `pkill -SIGUSR2 waybar` reloaded waybar and the module came back (`Cor 44%`, child PID parented by waybar). No nixos-rebuild required.
**Commit:** `85eeef9`

## 2026-05-23 — corne-reconnect-loop-recurrence-bt-service-ordering-cycle

**Symptom:** Corne BLE keyboard back in the Connected↔Disconnected loop again, ~2 weeks after the 2026-05-22 fix (`46cae11`/`33fc458`) supposedly resolved it. Same `read_pnpid_cb` ATT 0x0E failures.
**Affected:** host `verse`, user `eksno`. `system/lib/power-mode/default.nix:1046` (the `bluetooth-no-autosuspend` service, now replaced by a `powertop.service` `ExecStartPost`).
**Root cause:** The 2026-05-22 fix was logically correct but **never ran**. It created `systemd.services.bluetooth-no-autosuspend` ordered `after = [ "powertop.service" ]` + `wantedBy = [ "multi-user.target" ]`. But NixOS's own `powertop.service` is `After=multi-user.target`, so the three units formed an ordering cycle: `bluetooth-no-autosuspend → powertop → multi-user.target → bluetooth-no-autosuspend`. systemd silently **deleted the bluetooth-no-autosuspend job** to break the cycle (`Found ordering cycle … Job … deleted`), so the BT radio re-pin never executed. powertop's `--auto-tune` set `power/control=auto` on the controller unopposed, it autosuspended after 1s idle, and the BLE link desynced on reconnect exactly as before. 5-whys: loop ← radio re-pin never applied ← service job deleted ← ordering cycle ← anchored a unit both `after powertop` and `wantedBy multi-user.target` while powertop is itself `after multi-user.target`.
**Investigation:**
1. `systemctl status bluetooth-no-autosuspend` → `inactive (dead)` with the boot-log line `multi-user.target: Found ordering cycle … Job bluetooth-no-autosuspend.service/start deleted to break ordering cycle`. That was the smoking gun — the unit existed but its job was dropped every boot.
2. Confirmed live damage: BT controller `usb 3-10` (`8087:…`, class e0) at `power/control=auto`, `autosuspend_delay_ms=1000` — the bad state the service was meant to prevent.
3. `systemctl cat powertop.service` → `After=multi-user.target`, `Type=oneshot`, `RemainAfterExit=yes`. That `After=multi-user.target` is the third edge that closes the cycle; not obvious without reading the NixOS-generated unit.
4. Device-recovery side: `bluetoothctl info` showed Corne (`C8:5B:C1:B5:9B:F3`) `Trusted: yes` but `Paired: no / Bonded: no` despite a bond dir on disk — a one-sided/desynced bond driving the Trusted auto-connect loop. `pair` stalled at "Attempting to pair" until **bluetoothd was restarted** to clear stuck Adv-Monitor churn; then `trust` + `pair` (session held open, not piped `quit`) bonded cleanly and `event18 → "Corne Keyboard"` appeared. Dead end worth noting: piping `pair` immediately followed by `quit` aborts the in-flight pairing — the session must stay open ~10–15s.
**Fix:** Replaced the separate cyclic unit with `systemd.services.powertop.serviceConfig.ExecStartPost = "${bt-no-autosuspend}";`. It runs immediately after `--auto-tune` within powertop's own oneshot and introduces no new unit anchored to `multi-user.target`, so a cycle is structurally impossible. `powerManagement.resumeCommands` re-pin kept for resume. Verified post-rebuild: new generation active, no failed units, `powertop.service` shows the `ExecStartPost`, no ordering-cycle log.
**Collateral (process lesson, not a code bug):** Applying this via `./update.sh` was disruptive — `update.sh` runs `nix flake update` first, which bumped nixpkgs unstable to `…20260521.f83fc3c`; the resulting `switch` restarted systemd + the graphical stack, tore down the Hyprland/uwsm session (`user@1000.service` deactivated, `switch-to-configuration` exited 101, Discord coredumped), and logged the user out with loss of open app state. For a small `system/` change, prefer a plain `nixos-rebuild switch` without a flake bump, and warn before any switch that can restart the display manager.
**Commit:** `36a6102`

## 2026-05-22 — corne-bluetooth-connect-disconnect-loop-after-idle

**Symptom:** Corne (ZMK) BLE keyboard repeatedly flips Connected → Disconnected → Connected every ~2s. Triggered after the laptop sits idle for a while; once it starts, only a full forget + re-pair from scratch recovers it.
**Affected:** host `verse`, user `eksno` (also applies to `lewis` — shared module). `system/lib/power-mode/default.nix:1026` (`powerManagement.powertop.enable`), `system/hosts/verse/bluetooth.nix:10` (`btusb enable_autosuspend=0`).
**Root cause:** `powerManagement.powertop.enable = true` runs `powertop --auto-tune` as a boot oneshot, which writes `power/control=auto` to **every** USB device — including the Intel BT controller (`8087:0033`, USB class e0/01/01) — overriding the per-host `btusb enable_autosuspend=0` modprobe option. The radio then autosuspended after ~1s idle (`autosuspend_delay_ms=1000`, `power/wakeup=disabled`). When the keyboard re-advertised after idle, the suspended/desynced controller couldn't complete encryption, so bluetoothd's HID-over-GATT reads (PnP ID, HID Information, Report Reference descriptors) all failed with ATT 0x0E "Request attribute has encountered an unlikely error" → HoG never attached → link dropped and retried in a tight loop. 5-whys: loop ← HID GATT reads fail ← encryption/link desync on reconnect ← BT controller autosuspended on idle ← USB `power/control=auto` ← powertop --auto-tune set it despite `enable_autosuspend=0` ← blanket battery optimization never excluded the radio.
**Investigation:**
1. `journalctl -u bluetooth` showed the 2s cycle: `rap_accept RAP unable to attach` (benign BlueZ 5.86 ranging noise) + `read_pnpid_cb`/`info_read_cb`/`report_reference_cb` all failing with ATT 0x0E for `C8:5B:C1:B5:9B:F3`.
2. `bluetoothctl info` confirmed Paired/Bonded/Trusted yes, random static address, Modalias `v1D50` (OpenMoko VID = ZMK), appearance 0x03c1 (HID keyboard). Bond + GATT cache present in `/var/lib/bluetooth/2C:33:58:44:27:4D/`.
3. `btusb enable_autosuspend` module param read `N` — so the existing modprobe fix *was* loaded, ruling it out as sufficient. **This was the key dead end that pointed upstream:** the param was correct yet the device still showed `power/control=auto`.
4. Walked sysfs from `hci0` to the USB device `usb3/3-10`: `power/control=auto`, `autosuspend_delay_ms=1000`, `wakeup=disabled` — i.e. autosuspending after 1s regardless of the module param.
5. Grepped for what sets USB autosuspend → `powerManagement.powertop.enable = true`. `powertop --auto-tune` writes `auto` to all USB devices at boot, clobbering the module param. User context ("happens after idle / BT sleeps") matched exactly.
**Fix:** In `system/lib/power-mode/default.nix`, added a `bt-no-autosuspend` script (matches USB BT controllers by device class e0/01/01, writes `power/control=on`) wired into a `systemd.services.bluetooth-no-autosuspend` oneshot ordered `after = [ "powertop.service" ]` (wins the boot race) and into `powerManagement.resumeCommands` (re-applies on resume). Live relief applied same session via `tee .../power/control`. Stale bond cleared once with `bluetoothctl remove` + re-pair to recover the already-desynced link.
**Commit:** `33fc458`

## 2026-05-21 — wireplumber-soft-mixer-mutes-speaker-and-mic-on-cold-boot

**Symptom:** After a reboot, built-in speaker AND mic both completely dead. Card enumerates, PipeWire/Wireplumber running, Speaker sink + Mic source present in `wpctl`, CS35L41 amps bound cleanly (calibration applied, firmware loaded) — yet no playback and mic records pure digital silence (rms=0).
**Affected:** host `verse`, user `eksno`. `system/hosts/verse/default.nix` (the reverted `services.pipewire.wireplumber.extraConfig."51-cs35l41-soft-mixer"` block).
**Root cause:** An `api.alsa.soft-mixer = true` Wireplumber rule (added to keep the CS35L41 fed at full analog regardless of sink %) tells PipeWire to stop managing the hardware mixer's **volume and mute** for the whole ALSA device — playback and capture. While PipeWire was already running it worked (hw controls were already open), but a cold boot brought the hardware `Master` up at 0% + muted and `Capture`/`Dmic0` muted, and PipeWire — now in soft-mixer mode — never unmutes them or sets up the capture route. Per PipeWire docs soft-mixer "leaves the hardware mixer untouched," which on this card means nothing opens the analog path on boot.
**Investigation:**
1. `cat /proc/asound/cards` + `wpctl status` — card present, sink/source nodes present → not a driver/topology failure.
2. `dmesg | grep cs35l41` — both amps bound fine, R0 calibration applied → smart-amp init was healthy, ruled out the racy CS35L41 probe (cf. commit 3a530bd "audio race").
3. `amixer -c sofhdadsp sget Master` → `0% [-65.25dB] [off]`; `Capture`/`Dmic0` also `[off]`. Manually unmuting Master restored playback, but manually unmuting `Dmic0`/`Capture` did NOT restore mic — it still recorded silence, because the DMIC capture **route** (not just gain) needs PipeWire/UCM to set it up, which soft-mixer suppresses.
4. Concluded the soft-mixer rule is the root cause and its benefit (never even confirmed audible — the loudness ceiling it chased turned out to be CS35L41 firmware behavior, unrelated) does not justify the regression.
**Fix:** Removed the `51-cs35l41-soft-mixer` Wireplumber block from `system/hosts/verse/default.nix`. PipeWire resumes managing the hardware mixer and unmutes/routes playback + capture on boot as before. Kept the 1000% pulsemixer cap (harmless). Runtime: `amixer -c sofhdadsp sset Master 100% unmute` restores playback immediately; mic needs the pipewire restart from the rebuild to re-establish the route.
**Commit:** `2ce36c2`

## 2026-05-20 — wireshark-cli-hash-mismatch-recurrence-eksno

**Symptom:** `./update.sh` aborted with the same `wireshark-cli-4.6.5` hash mismatch (`got: sha256-Zvrwxjp4LK2J3QnxmPxKKrU01YHQvPyp54UWzeGNCjA=`) seen on 2026-05-05, blocking an unrelated audio change.
**Affected:** `system/users/eksno/programs/default.nix:44`. `jorge` was already commented out from the prior fix; eksno's `wifite2` line had been re-uncommented since `d7914d6`.
**Root cause:** Upstream `wireshark-cli` source hash still not fixed in nixpkgs unstable. Same pure-upstream issue as before. `nix flake update` in `update.sh` keeps pulling the broken revision.
**Investigation:**
1. Greppped FIXES.md per CLAUDE.md rule — found the 2026-05-05 "recurring" entry with the exact same hash and the documented fix (comment `wifite2`).
2. Confirmed jorge's `wifite2` is still commented; only eksno's needed re-applying.
3. No new investigation needed — re-applying the documented fix.
**Fix:** Re-comment `wifite2` in `system/users/eksno/programs/default.nix:44`.
**Commit:** `71625e7`

## 2026-05-06 — waybar-icon-percentage-color-mismatch

**Symptom:** In waybar, the audio icon and the percentage rendered in different colors — icon was Catppuccin purple, value was Startino pink. Same pattern would have hit backlight if anyone had looked closely.
**Affected:** `dotfiles/default/waybar/config:30,47,48`. Any waybar module using inline pango `<span color='#...'>` overrides.
**Root cause:** The pulseaudio and backlight modules' `format` strings embedded hardcoded Catppuccin Mocha hexes inline (`<span color='#cba6f7'>{icon}</span>` for mauve, `#f9e2af` for yellow). The CSS sets the module color via `@mauve`/`@yellow`, but inline pango spans take precedence on the wrapped character only. Result: the icon stayed at the Catppuccin hex (purple/yellow) while the bare percentage outside the span rendered in the CSS variable. Visible on Neptune because Startino collapses `mauve` → pink — icon ended up purple, value ended up pink.
**Investigation:**
1. Suspected the rosewater/clash session (just landed) had broken something — checked. Rosewater was a separate concern; this was independent.
2. `grep -n "color='#" dotfiles/default/waybar/config` surfaced three inline overrides: `#f9e2af` (backlight icon), `#cba6f7` (pulseaudio icon), and the mute-state span. All Catppuccin Mocha hexes baked into the JSON.
3. Fix: drop the spans entirely. CSS already styles the whole module via `#pulseaudio { color: @mauve; }`, so removing inline overrides yields uniform color *and* lets palette changes propagate downstream automatically.
**Fix:** `format` simplified to `"{icon} {percent}%"` / `"{icon} {volume}%"`; format-muted simplified the same way. No CSS changes needed.
**Commit:** `415515f`

## 2026-05-06 — tmux-catppuccin-reset-also-nukes-window-customizations

**Symptom:** After adding `set -g @catppuccin_reset "true"` to fix the flavor-switch (see entry below), tmux lost the rounded window-status style and the `" #W"` window-name format — windows rendered with default catppuccin styling instead of the `@catppuccin_window_status_style "rounded"` and `@catppuccin_window_*_text` customizations set in `tmux.conf`.
**Affected:** `dotfiles/default/tmux/tmux.conf`. Anyone using `@catppuccin_reset` to switch flavors while also customizing window/status modules.
**Root cause:** The `%if @catppuccin_reset == true` block in `catppuccin_options_tmux.conf` unsets the entire `@thm_*` palette **and** `@catppuccin_window_status_style`, `@catppuccin_window_*_text`, all `@catppuccin_window_flags_*`, and the status separators. So `@catppuccin_reset` is a sledgehammer that clears user customizations along with stale palette values.
**Investigation:**
1. Re-read `catppuccin_options_tmux.conf:20-78` carefully — the `%if` block contains `set -Ugq` for the full `@thm_*` palette **plus** `@catppuccin_window_status_style`, `@catppuccin_window_text_color`, `@catppuccin_window_default_text`, etc. Roughly 30 unsets total, only a third of which are palette.
2. Considered re-applying user customizations after `run catppuccin.tmux` — would need to be done before catppuccin_tmux.conf finishes (it reads them during render-string construction). Ugly.
3. Considered running the plugin twice (reset, then re-run with customizations re-set) — also ugly.
4. Realized the cleanest fix is a surgical palette-only reset: just `set -gu @thm_*` for the 26 palette vars before the `run` line. Catppuccin's `%if` block runs only when `@catppuccin_reset` is set, so leaving it unset preserves the user customizations entirely.
**Fix:** Replace `set -g @catppuccin_reset "true"` in `tmux.conf` with 26 explicit `set -gu @thm_*` lines covering only the palette. Verified after reload: `@catppuccin_window_status_style rounded`, `@catppuccin_window_default_text " #W"`, and `@thm_bg "#171919"` (Neptune) all coexist correctly.
**Commit:** `0c51848`

## 2026-05-06 — tmux-catppuccin-flavor-switch-needs-reset

**Symptom:** After switching `@catppuccin_flavor` from `"mocha"` to `"neptune"` (Startino flavor file symlinked into the plugin's `themes/` dir) and reloading via `tmux source-file ~/.config/tmux/tmux.conf`, the status bar kept rendering with mocha colors. `tmux show-options -g | grep @thm_bg` returned `#1e1e2e` (mocha) instead of `#171919` (neptune).
**Affected:** any flavor switch on the `catppuccin/tmux` plugin. `dotfiles/default/tmux/tmux.conf`.
**Root cause:** Startino's flavor file (and Catppuccin's own ones) sets `@thm_*` with `set -ogq` — the `-o` flag means "only set if not already set." Mocha's values from the previous load were still in tmux's option memory, so every `set -ogq @thm_bg "#171919"` was a silent no-op. A fresh tmux server would have worked; an in-place reload of the same server would not.
**Investigation:**
1. Confirmed the symlink was correct: `~/.config/tmux/plugins/tmux/themes/catppuccin_neptune_tmux.conf` → `~/themes/ports/tmux/dist/catppuccin_neptune_tmux.conf`, file readable, contained `set -ogq @thm_bg "#171919"`.
2. Read `catppuccin_tmux.conf:1` — confirmed it sources the flavor file via `source -F "#{d:current_file}/themes/catppuccin_#{@catppuccin_flavor}_tmux.conf"`. So the right file *was* being sourced.
3. `tmux show-options -g` showed `@catppuccin_flavor neptune` but `@thm_bg "#1e1e2e"` — proving the source ran but the writes had no effect.
4. Read `catppuccin_options_tmux.conf` — found a `%if @catppuccin_reset == true` block that does `set -Ugq @thm_*` (unset) for the entire palette. Catppuccin's own flavor-switching docs (the comment block in that file showing dark/light theme hooks) set `@catppuccin_reset "true"` before re-running the plugin for exactly this reason.
**Fix:** Add `set -g @catppuccin_reset "true"` immediately before the `run ~/.config/tmux/plugins/tmux/catppuccin.tmux` line in `tmux.conf`. Catppuccin's options conf clears the reset flag (`set -Ug @catppuccin_reset` at the bottom of the `%if` block) so it doesn't accumulate.
**Commit:** `22fd835`

## 2026-05-05 — hypr-mirror-direction-for-correct-aspect-on-external

**Symptom:** External VG258 (1920x1080, 16:9) mirroring laptop eDP-1 (2880x1800, 16:10) showed low-resolution, aspect-distorted output on the external. Laptop looked fine.
**Affected:** host `lewis`, user `jorge`. `dotfiles/default/hypr/users/jorge/default/monitor.conf`.
**Root cause:** Hyprland blit-scales the source's framebuffer into the mirror's physical resolution. With eDP-1 as source (logical 2304x1440, 16:10) and HDMI-A-1 as mirror (1920x1080, 16:9), the external got a downscaled + horizontally-squashed image. The mirror destination cannot crop or letterbox — only scale.
**Investigation:**
1. First attempt: kept eDP-1 as source, set HDMI-A-1 to mirror it at 119.98Hz. Refresh now matched but res/AR still wrong (this is the inherent blit-scale behavior; no Hyprland flag changes it).
2. Searched `git log --all --grep=mirror` and FIXES.md — found prior commits `b41b21d`, `9056a37`, `1788ef5` from 2026-03 that solved the same problem by **flipping the direction**.
3. Confirmed flip is the only fix: external is the lower-res panel, so making it the source means the framebuffer is rendered at its native res — sharp and correct AR on the external. Laptop accepts the 16:9 framebuffer stretched into its 16:10 panel as the unavoidable trade.
**Fix:** Made `HDMI-A-1, 1920x1080@119.98, 0x0, 1` the source and set `eDP-1, ..., mirror, HDMI-A-1`. Existing glasses rule already mirrors HDMI-A-1, so the chain stays coherent.
**Commit:** `e241ad1`

## 2026-05-05 — nixpkgs-wireshark-source-hash-mismatch-recurring

**Symptom:** Same `wireshark-cli-4.6.5` hash mismatch (`got: sha256-Zvrwxjp4LK2J3QnxmPxKKrU01YHQvPyp54UWzeGNCjA=`) re-appeared after the next `./update.sh` run despite the 2026-05-05 lock revert.
**Affected:** `system/users/jorge/programs/default.nix:51`, `system/users/eksno/programs/default.nix:41`. Anything in either user's closure rebuilding against nixpkgs unstable.
**Root cause:** `update.sh` runs `nix flake update` unconditionally (line 50), so reverting `flake.lock` is a one-shot workaround that gets undone on the next rebuild. Upstream nixpkgs hasn't shipped a fix yet.
**Investigation:**
1. Confirmed the failing dep chain: `wifite2 → wireshark-cli → fetched source`. Nothing else in the closure pulled `wireshark-cli`.
2. Considered: (a) overriding the hash via overlay, (b) reverting lock + skipping `nix flake update`, (c) dropping `wifite2`. (a) is the most general but makes the closure depend on knowing the post-fix hash before upstream ships it; (b) regresses every other package; (c) is reversible with one comment.
3. Verified `wifite2` is a wifi-auditing tool (Python wrapper around aircrack-ng/reaver) — removing it does NOT affect day-to-day NetworkManager wifi.
**Fix:** Comment out `wifite2` in both `jorge/programs/default.nix` and `eksno/programs/default.nix` until nixpkgs ships a working `wireshark-cli` revision. Each line carries a pointer back to this entry so future-Jorge knows why it's commented.
**Commit:** `d7914d6`

## 2026-05-05 — nixpkgs-wireshark-source-hash-mismatch

**Symptom:** `./update.sh` failed mid-build with `error: hash mismatch in fixed-output derivation '/nix/store/7sj663dx4vl5n972s0825n6c3xxsvk7d-source.drv'` (specified `sha256-U30OJ8m+L/EVLN7NrqWNl77IMaO2cnw2N5uWzLVJE30=`, got `sha256-Zvrwxjp4LK2J3QnxmPxKKrU01YHQvPyp54UWzeGNCjA=`) under `wireshark-cli-4.6.5`, blocking `wifite2-2.7.0` and the whole system closure.
**Affected:** host `lewis` (and any host with `wifite2` in its package list, e.g. eksno on verse). Triggered by `flake.lock` bump from nixpkgs `4bd9165` (2026-04-14) → `15f4ee4` (2026-04-30).
**Root cause:** Upstream wireshark replaced the 4.6.5 source tarball without changing the version, while the `15f4ee4` nixpkgs commit still pins the old sha256. Pure-upstream issue, no local code involved.
**Investigation:**
1. Sandbox-built `nixosConfigurations.lewis.config.system.build.toplevel` against the pre-bump lock and it succeeded — confirmed our changes weren't at fault.
2. `update.sh` always runs `nix flake update` before rebuild (line 50), so re-running it would just re-pull the broken pin.
3. Considered (a) overriding wireshark to the updated hash, (b) dropping `wifite2`, (c) reverting the lock. Picked (c) — defers the upgrade until upstream fixes the hash, no other changes needed.
**Fix:** `git checkout 14d87b3 -- flake.lock` to restore the prior nixpkgs pin (`4bd9165`), then `sudo nixos-rebuild switch --flake ./#lewis --impure` directly (bypassing `update.sh`'s lock-update step).
**Commit:** `7f7cd9c`

## 2026-05-04 — xr-linux-driver-permissions-and-shm

**Symptom:** Newly-packaged `xr-linux-driver` (Rayneo Air 3s Pro / 1bbb:af50) systemd user service kept exit-code 1 / segfaulting in a tight auto-restart loop. Manual `sudo bash smoketest.sh` from `.scratch/xrtest/` worked, but `systemctl --user start xr-driver` did not — in three distinct ways across iteration cycles.
**Affected:** host `lewis`, user `jorge`. `system/users/jorge/dev/xr-driver/{package.nix,default.nix}`, `system/users/jorge/dev/default.nix`. Anyone packaging this driver under systemd-logind will hit at least the udev gotchas.
**Root cause:** Three independent issues stacked, each masked by the auto-restart loop and similar-looking segfault traces.
1. **Stale `/dev/shm/xr_driver_state`**: an earlier sudo smoke test created `/dev/shm/xr_driver_state` owned by root mode 0644. `/dev/shm` has the sticky bit, so the user service couldn't unlink or `fopen("w")` the file. `state.c::write_state` calls `fprintf(fp,…)` without checking `fp != NULL`, so `fprintf(NULL,…)` segfaulted *between* "Using hardware id" and "Starting up XR driver" with a backtrace that pointed at `_IO_fprintf` — easy to misread as a fortify/libc issue.
2. **Rayneo udev rule is USB-only**: upstream's `70-rayneo-xr.rules` is one line, `SUBSYSTEM=="usb", … TAG+="uaccess"`. systemd-logind doesn't propagate uaccess from a USB parent to a `hidraw` child. `libhidapi` opens `/dev/hidrawN`, so the daemon fails with "RayNeo driver, failed to establish a connection". The Viture rule in the same repo *does* match all four subsystems (usb, hidraw, hiddev, ttyACM); Rayneo just got missed.
3. **uinput rule grants no access**: upstream's `70-uinput-xr.rules` is `KERNEL=="uinput", OPTIONS+="static_node=uinput"` — sets the static node but leaves it 0600 root:root. `libevdev_uinput_create_from_device` returns `EACCES`, which the proprietary `libRayNeoXRMiniSDK.so` doesn't expect and segfaults inside `XRWorkQueue::Enqueue` shortly after.
**Investigation:**
1. First crash looked like a fortify-source false positive (backtrace via `__fprintf_chk`). Disabling `_FORTIFY_SOURCE` via `hardeningDisable = ["fortify" "fortify3"]` was a dead end — the fortify call was a symptom, the real fault was a NULL `FILE*`.
2. Built the package with `-DCMAKE_BUILD_TYPE=RelWithDebInfo` + `dontStrip = true`, ran `addr2line -e .xrDriver-wrapped 0x1a891` on the in-log offset → `state.c::write_state`. Reading the source showed the `fopen` of `/dev/shm/xr_driver_state` was unchecked, then `ls -la /dev/shm/xr_driver_state` revealed root ownership from the prior sudo smoke test. `sudo rm` cleared it.
3. Next failure: "RayNeo driver, failed to establish a connection". `udevadm info /dev/hidraw3` showed `TAGS=:seat:` (no uaccess) and the file mode was `crw-------`. Compared `70-rayneo-xr.rules` to `70-viture-xr.rules`; the latter has explicit `SUBSYSTEM=="hidraw"` lines, the former doesn't. **Note:** hidraw indices shuffle on hot-replug — use `udevadm info /dev/hidrawN | grep ID_VENDOR_ID` to find the right node, don't trust a number from earlier in the session.
4. Final failure: `libevdev.libevdev_uinput_create_from_device: Permission denied` followed by SDK segfault. `getfacl /dev/uinput` showed no ACL; the udev rule didn't tag uaccess. `lsd`/`eza` does *not* show the `+`/`@` ACL marker in `ls -la` output — use `getfacl` to confirm ACLs.
**Fix:**
- `system/users/jorge/dev/xr-driver/package.nix` postPatch: append `SUBSYSTEM=="hidraw", KERNEL=="hidraw[0-9]*", ATTRS{idVendor}=="1bbb", MODE="0660", TAG+="uaccess"` to `udev/70-rayneo-xr.rules`; rewrite `udev/70-uinput-xr.rules` to `KERNEL=="uinput", MODE="0660", TAG+="uaccess", OPTIONS+="static_node=uinput"`.
- Manual one-time cleanup: `sudo rm /dev/shm/xr_driver_state`. Not a recurring issue under the user service since the daemon now owns the file from creation.
- After activation, `sudo udevadm trigger --action=add` against the relevant subsystems (hidraw + misc) to apply rules to already-plugged devices — rules only fire on `add` events, not retroactively.
**Commit:** `0c60006` (hidraw rule), `4c54b1d` (uinput rule). The `/dev/shm` cleanup is a one-shot that doesn't need a commit.

## 2026-04-27 — hypr-screenshot-color-management-tint

**Symptom:** `wayshot` PNGs taken on `lewis` (`Super+v` region capture and bare `wayshot -o eDP-1 ...`) looked tinted / washed-out / "filtered" when viewed in Chrome, Claude desktop, etc., but the screen itself looked normal. No night-light or red-shift utility involved.
**Affected:** host `lewis`, user `jorge`. New file `dotfiles/default/hypr/users/jorge/default/render.conf`. Same root cause would hit any other Hyprland host on this flake (verse/eksno, chuu/nabi, lappy/teto, chrono/teto) but only jorge's config was touched per request scope.
**Root cause:** Hyprland 0.49+ flipped `render:cm_enabled` to `1` by default. With CM on, the compositor composes its framebuffer in a CM working space and `hyprctl monitors` reports `colorManagementPreset: "srgb"` for the output. `zwlr-screencopy` hands that buffer to `wayshot`, but `wayshot` writes a PNG tagged plain sRGB / gamma 2.2 with **no embedded ICC profile**. The pixel data and the file's color tag disagree, so any downstream viewer assuming sRGB decodes it with a slightly wrong transfer/primaries — visually a global colorgrade. The on-screen image is unaffected because the monitor receives the correctly-CM'd output, not the captured buffer.
**Investigation:**
1. Ruled out a night-light / shader path: `pgrep -af 'hyprsunset|wlsunset|gammastep|redshift'` had no hits, `hyprctl getoption decoration:screen_shader` returned empty, `misc:cm_auto_hdr` doesn't exist on this build. So no user-installed filter is in play.
2. `hyprctl getoption render:cm_enabled` → `int: 1, set: false` (compositor default, not user-set). `hyprctl monitors -j` confirmed `colorManagementPreset: "srgb"` on eDP-1, which is what Hyprland reports when CM is active for an SDR output.
3. `identify -verbose` on the three `wayshot-*.png` artifacts in the worktree showed `Colorspace: sRGB`, `Gamma: 0.454545`, no ICC profile chunk — confirming the file/buffer mismatch hypothesis instead of a wide-gamut PNG that was simply being rendered narrowly.
4. Considered three fixes: (a) `render:cm_enabled = 0` — one-line, kills CM globally for Hyprland; (b) re-tag in the screenshot pipeline via `magick "$TMP" -strip -colorspace sRGB`, keeping CM on for normal use; (c) live with it. Picked (a): single non-HDR Samsung laptop panel, no CM benefit being captured today, and (b) only patches `screenshot-region.sh` — bare `wayshot` calls would still produce wrong files.
**Fix:** New `dotfiles/default/hypr/users/jorge/default/render.conf` setting `render { cm_enabled = 0 }`. Sourced automatically via the existing `source = ~/.config/hypr/users/jorge/default/**.conf` glob in `users/jorge/default.conf`. Applied live with `hyprctl reload`; `hyprctl getoption render:cm_enabled` afterwards returned `int: 0, set: true`. Verified with a fresh `wayshot -o eDP-1 /tmp/cm-off-test.png` — now matches the visible screen.
**Commit:** `f3eee94`

## 2026-04-22 — hypr-screenshot-pipeline-swallowed-errors

**Symptom:** `Super+v` on `lewis`/`jorge` stopped landing an image on the clipboard. `wl-paste --list-types` after a screenshot showed `application/glfw+clipboard-<pid>` + text types — i.e. a prior GLFW app was still the clipboard owner, `wl-copy` never took it. Slurp overlay appeared and the drag worked; no notify-send fired; Hyprland bind and symlink were fine.
**Affected:** host `lewis`, user `jorge`. `dotfiles/default/hypr/shared/scripts/screenshot-region.sh`.
**Root cause:** The capture pipeline was `wayshot -o "$SRC" - 2>/dev/null | magick - -crop ... png:- | wl-copy -t image/png` under `set -euo pipefail`. Two failure modes can break it silently: (a) wayshot on this Intel-only `lewis` box still emits the `MESA-LOADER: failed to open nvidia-drm` loader warning on stderr which is muted by `2>/dev/null`, and under `set -e` + `pipefail` any transient nonzero wayshot exit (or mid-pipeline EPIPE from magick finishing first) kills the pipeline with no clipboard write and no visible trace; (b) slurp cancelled via Esc/single-click takes the `|| exit 0` branch without any notify-send, which looks identical to "nothing happened" to the user. No log, no notification, prior clipboard contents untouched.
**Investigation:**
1. Grepped FIXES.md for "screenshot" → three prior entries (`fractional-scaling`, `mirrored-output`, `mirror-logical-size`). Ruled out the mirror/scale regressions: `hyprctl monitors all -j` showed laptop-only eDP-1 at scale 1.25, `mirrorOf: "none"`, so the logical-remap no-op path should hit.
2. Ran the pipeline manually: `wayshot -o eDP-1 - | magick - -crop "400x300+100+100" +repage png:- | wl-copy -t image/png` → `wl-paste --list-types` reported `image/png`. Pipeline works end-to-end when run cold. So the bug is state-dependent, not a straight logic bug.
3. Checked bind wiring: `hyprctl binds` showed `Super+v` → `~/.config/hypr/shared/scripts/screenshot-region.sh` → symlink to the repo path. Active layout is `qwerty.conf`, so the expected bind is the active one.
4. `readlink -f` on the symlink and `ls -la` on the path confirmed the activation script deployed the live version. Rules out "edits not applied."
5. Instrumented the script: redirected stderr via `exec 2> >(tee -a /tmp/screenshot-region.log >&2)` and added per-step exit-code checks + `notify-send` on failure. First user retry: log had only the date header, nothing else. That meant the script exited at the `read -r ... < <(slurp ...) || exit 0` line — slurp was cancelled or returned empty. Not our failure mode, but exposed that a cancelled slurp is indistinguishable from a silent failure at this instrumentation level.
6. Split the pipeline into tempfile-staged steps (`wayshot -> $TMP`, `magick $TMP -> $CROP`, `wl-copy < $CROP`) with explicit exit-code and size checks on each. Second retry logged `slurp rc=0 out='358 635 630 259 eDP-1'`, `wayshot ok: 660946 bytes`, `crop ok: 5511 bytes`, `wl-copy ok`, `post-clipboard types: image/png`. User confirmed paste worked in the target app.
7. Dead ends / ruled out: wayshot itself failing (`wayshot -o eDP-1 /tmp/x.png` produces a valid 549KB PNG, exits 0 — the MESA line is a warning, not an error); stale clipboard owner blocking wl-copy (wl-copy unconditionally takes ownership when it runs, so the GLFW owner we saw was the survivor of a prior no-op run, not an interposing process).
   **Fix:** Rewrote the capture tail in `screenshot-region.sh` to stage through tempfiles instead of a pipeline, with `set -uo pipefail` (dropped `-e`) and explicit `die` / `notify-send` on every nonzero rc or empty output. Also made silent-abort paths (slurp cancel, zero-size region) exit `0` without a notification, and every real failure (output-unknown, scale-missing, wayshot/magick/wl-copy errors) now raises a notify-send so the user sees it next time instead of silently falling back to whatever was on the clipboard before.
**Commit:** `98d031a`

## 2026-05-03 — waybar-network-signal-stuck-on-ewma

**Symptom:** Waybar's wifi `{signaldBm}` placeholder displayed a value (e.g. `-52 dBm`) that never moved, even with `interval: 1` and a hard waybar restart. `iw dev wlo1 link` reported a different, slightly fluctuating value (`-58` ↔ `-60`) at the same moments.
**Affected:** verse/eksno, `dotfiles/default/waybar/config` (network module), `dotfiles/default/waybar/scripts/network.sh` (new).
**Root cause:** Waybar's built-in network module reads `NL80211_STA_INFO_SIGNAL_AVG` (or beacon-signal-avg), not `NL80211_STA_INFO_SIGNAL`. That AVG is an EWMA computed by the kernel/driver over the lifetime of the connection. After ~70 minutes of association each new sample contributes a vanishing fraction, so the value freezes for all practical purposes — the bar looked broken but was reporting exactly what the kernel handed it.
**Investigation:**
1. Suspected SIGUSR2 wasn't re-arming the interval timer. Hard-restarted waybar; no change. Ruled out reload semantics.
2. Sampled `iw dev wlo1 link` once per second — value held at `-58` for 14s, drifted to `-57` once. Concluded WiFi RSSI on a stationary laptop genuinely is mostly flat. Premature "this is fine" answer to user.
3. User pushed back: waybar showed `-52` while `iw` showed `-58`. That's a 6 dBm gap, not just smoothing — different *source*.
4. `iw dev wlo1 station dump` exposes both `signal:` (instant, with min/max bracket) and `signal avg:` plus `beacon signal avg:`. The AVG values matched waybar's reading; instant matched `iw link`. Confirmed waybar reads the AVG field.
**Fix:** Added `dotfiles/default/waybar/scripts/network.sh` — continuous-JSON custom module that shells out to `iw dev <iface> link` every 1s and emits `{signal} dBm` from the instantaneous field. Replaced the built-in `network` module with `custom/network` in waybar config. Tooltip now shows SSID, signal, freq, and TX bitrate (more useful than the old empty tooltip anyway).
**Commit:** `6f40c3d`

## 2026-05-02 — hyprland-layerrule-syntax-changed-0.54

**Symptom:** Adding `layerrule = noanim, tofi` to disable tofi's fade-in animation produced `Config error … invalid field noanim: missing a value` on `hyprctl reload`. Same shape for `blur, tofi` and every other rule keyword tested — it wasn't the effect name, it was the syntax itself.
**Affected:** verse/eksno (Hyprland 0.54.3), `dotfiles/default/hypr/shared/utility/layerrules.conf`.
**Root cause:** Hyprland 0.54 rewrote how `layerrule` is parsed. `handleLayerrule` in `src/config/ConfigManager.cpp:3024` now splits each comma-separated entry on the first **space** into a `key value` pair, with `match:<prop>` distinguishing matchers from effects. The old single-rule `layerrule = RULE, NAMESPACE` form was removed without a back-compat shim — supplying just `noanim` (no space, no value) trips the very first guard and returns the misleading "missing a value" error. Independently, the effect identifiers were renamed to snake_case (`no_anim`, `blur_popups`, `ignore_alpha`, `dim_around` — see `src/desktop/rule/layerRule/LayerRuleEffectContainer.cpp`).
**Investigation:**
1. `hyprctl configerrors` was empty initially, but `hyprctl reload config-only` re-parses and prints fresh errors. The empty output earlier was misleading because errors are only re-emitted on reload.
2. Tried four variants via `hyprctl keyword layerrule …` — comma vs no-comma, `namespace:tofi`, regex `^(tofi)$` — all returned the same "invalid field NOANIM: missing a value." Switched to other rules (`blur, tofi`, `ignorezero, tofi`) — same error. That ruled out tofi/namespace and pointed at the keyword parser itself.
3. Considered the new special-category block form (`layerrule NAME { match:namespace = …; no_anim = 1 }`) since `addSpecialCategory("layerrule", {.key = "name"})` is registered. Wrote it that way; got `config option <layerrule tofi-instant:match:namespace> does not exist` on every sub-key. Looks like `addSpecialConfigValue` for the match/effect keys runs in `reloadRuleConfigs()` but the parser still doesn't expose them through the block form in 0.54.3 — at least not in a way that worked here. Abandoned the block route.
4. Read `handleLayerrule` directly. The parser splits each comma-entry on the first space; `match:` prefix means matcher, otherwise it's an effect; the rest of the string after the space is the value. That's the active code path, not the block form.
**Fix:** Rewrote `layerrules.conf` as `layerrule = match:namespace ^(tofi)$, no_anim 1`. `hyprctl reload config-only` followed by `hyprctl configerrors` now returns empty, and tofi's layer surface skips the global `animation = fade, 1, 10, default` (1000 ms) — the perceived "tofi takes a second to open" lag is gone.
**Commit:** `1707a3a`

**Follow-up (362279e):** Syntax was correct but tofi still faded in/out. Tofi's layer-shell namespace is hardcoded as `"launcher"` in `src/main.c` (`zwlr_layer_shell_v1_get_layer_surface(..., "launcher")`), not `"tofi"` — so `match:namespace ^(tofi)$` never matched. Changed the regex to `^(launcher)$`. Lesson for future layer rules: the `app_id`/process name is *not* the layer namespace — always check the upstream source for the literal string passed when creating the layer surface, or `hyprctl layers` while the surface is alive.

## 2026-04-25 — builtin-audio-disappeared-wireplumber-profile-off

**Symptom:** Built-in laptop speakers and mic vanished from the audio menu. Only the USB Hollyland wireless microphone and (when paired) Bluetooth headset showed up. PipeWire fallback "Dummy Output" was the only sink. Hardware was untouched.
**Affected:** verse/eksno (ASUS Zenbook UX3405MA Meteor Lake), runtime WirePlumber state in `~/.local/state/wireplumber/{default-profile,default-routes,default-nodes}`. No nix-config files changed.
**Root cause:** WirePlumber had the `alsa_card.pci-0000_00_1f.3-platform-skl_hda_dsp_generic` card sitting on profile `off` and refused to switch. The only `HiFi` profile the card currently enumerates is named `HiFi (HDMI1, HDMI2, HDMI3, Headphones, Mic1, Mic2)` and was reporting `available=no`, because UCM gates that profile on Headphones-jack-detect and nothing was plugged in. The saved `default-routes` referenced a *different* profile name with `…Speaker)` instead of `…Headphones)` — proof the SOF/UCM topology profile naming changed under a recent unstable bump (kernel 7.0.1, NixOS 26.05 unstable). The previously-elected profile name no longer existed, the replacement was unavailable, so WP picked `off`.
**Investigation:**
1. `fastfetch` confirmed verse/eksno, kernel 7.0.1. `wpctl status` showed device 44 (Meteor Lake-P HD Audio Controller) listed under Devices but exposing zero Sinks, only "Dummy Output" — so PipeWire saw the card but had no endpoints for it. Active source was the Hollyland USB mic only.
2. Ruled out kernel/firmware: `journalctl -k -b 0 | grep -iE "sof|hda"` showed `sof-audio-pci-intel-mtl` booting firmware 2.14.1.1, ALC294 codec attaching, both CS35L41 smart amps binding with calibrated DSP firmware, topology `intel/sof-ipc4-tplg/sof-hda-generic-2ch.tplg` loading, card0 `sofhdadsp` created with Mic/Headphone/HDMI inputs. ALSA layer was healthy. `cat /proc/asound/cards` confirmed card0 present.
3. `pw-dump` for device 44 → `params.Profile` = `off`, `EnumProfile` listed exactly one HiFi profile and it was `available=no`. That answered "why no sinks": no profile, no nodes.
4. `cat ~/.local/state/wireplumber/default-profile` named the HiFi profile correctly, but `default-routes` had history under a *different* profile name (`…Speaker)` vs `…Headphones)`) — meaning the topology had recently changed names underneath stable user state.
5. Considered: clearing all WP state files. Rejected as first step: too blunt and would also nuke per-app stream-properties, BT pairings' route prefs, etc. Tried the surgical path first.
**Fix:** `wpctl set-profile 44 1` forced the only HiFi profile active despite `available=no`. That immediately materialized 4 sinks (HDMI×3 + Headphones) and 2 internal mic sources. `systemctl --user restart wireplumber` then re-elected profiles cleanly — and on this pass the card actually came up with the *other* profile, `HiFi (…Speaker)`, exposing a true Speaker sink (priority-elected as default). Bumped volume from the saved 0.0 with `wpctl set-volume <id> 0.6` and unmuted. No code changes; no rebuild needed; survives reboot because the corrected profile/route is now persisted in `default-{profile,routes,nodes}`.
**Commit:** `639f4dd` (FIXES.md entry only — runtime state fix, no nix-config change)

## 2026-04-25 — tmux-restore-mosh-script-not-symlinked

**Symptom:** `~/.config/tmux/scripts/restore-mosh.sh` not found; tmux-resurrect couldn't restore mosh-client panes after the dotfiles activation-script migration.
**Affected:** verse/eksno, `system/lib/dotfiles.nix:73`, references from `dotfiles/default/tmux/tmux.conf:70` (`@resurrect-processes`).
**Root cause:** The 2026-04-19 migration from `symlink.sh` to `system/lib/dotfiles.nix` switched tmux from a directory symlink to file-level symlinks (because TPM writes into `plugins/`). The new block only linked `tmux.conf` and `tmux-nerd-font-window-name.yml`, dropping the `scripts/` subdirectory. `restore-mosh.sh` lived in the repo but was never deployed to `~/.config/tmux/`, so resurrect's exec path resolved to nothing.
**Investigation:**
1. `ls ~/.config/tmux/` → only `tmux.conf` + yml symlinks + `plugins/`. No `scripts/`. Repo path `dotfiles/default/tmux/scripts/restore-mosh.sh` exists and is executable, so the file isn't lost — just unlinked.
2. Read `system/lib/dotfiles.nix` tmux block → confirmed the activation script only `ln -sf`s the two known files. No glob, no scripts dir.
3. Considered switching tmux back to a full directory symlink. Rejected: TPM still needs to write into `plugins/`, which is the whole reason file-level symlinks were chosen. Cleanest fix is one extra `ln -sfn` for `scripts/` since it's a read-only dir of executables.
**Fix:** Added `ln -sfn "$_src/scripts" "$cfg/tmux/scripts"` to the tmux block in `system/lib/dotfiles.nix`. After `./update.sh`, `~/.config/tmux/scripts → nix-config/dotfiles/default/tmux/scripts` and resurrect can find `restore-mosh.sh`.
**Commit:** `36a6102`

## 2026-04-25 — norwegian-binds-ydotool-unicode-dropped

**Symptom:** After the 2026-04-19 swap from `wtype` to `ydotool type`, the `ALT+a/o/e` binds for å/ø/æ stopped working *everywhere* — not just Electron. The binds fired (Hyprland logged the exec, `ydotool type -- å` exited 0), but no character appeared in any focused window.
**Affected:** verse/eksno, `dotfiles/default/hypr/users/eksno/default/norwegian.conf`, `dotfiles/default/hypr/users/eksno/default/norwegian-type.sh` (new), `system/users/eksno/programs/default.nix`.
**Root cause:** `ydotool type` writes raw keycodes through `/dev/uinput`; the kernel then maps them through the active xkb layout. On a US layout, å/ø/æ have no native keycode. ydotool 1.0.4 falls back to GTK-style Ctrl+Shift+U `<hex>` Enter unicode entry, which only works when an input-method daemon (IBus / fcitx) is running. No IM is configured on this box, so the unicode-entry sequence is consumed as raw key chords with no effect — silently dropping the character in every app, not just Electron. The 2026-04-19 entry flagged this exact "open risk not yet verified" but the fix shipped anyway.
**Investigation:**
1. Verified the plumbing: `ydotoold.service` active, socket `/run/ydotoold/socket` (mode 0660, group `ydotool`), eksno in the `ydotool` group, `YDOTOOL_SOCKET` present in Hyprland's `/proc/$pid/environ`. So the daemon path is fine — the issue is what ydotool emits, not whether it reaches the kernel.
2. `ydotool type -- å` from a shell exited 0 but nothing showed up when focused on a kitty window. Combined with the 2026-04-19 note, that points at unicode handling in ydotool itself, not at permissions or layout fallback.
3. Considered installing fcitx5 + the unicode-IM module to make ydotool's Ctrl+Shift+U fallback succeed. Rejected: huge surface area (full IM stack, autostart, env wiring) for typing six characters.
4. Settled on a class-aware split: keep `wtype` for native Wayland surfaces (terminals, Zen, GTK, Qt) where it was always working, and use `wl-copy <char>` + `ydotool key Ctrl+V` only for Electron/Chromium clients. wtype writes via `virtual_keyboard_unstable_v1` which understands unicode strings directly, so it handles å/ø/æ fine wherever the protocol is honored. Old clipboard contents are restored ~200 ms after paste so the user's clipboard isn't permanently clobbered.
**Fix:** New script `dotfiles/default/hypr/users/eksno/default/norwegian-type.sh` branches on `hyprctl activewindow` class. `norwegian.conf` rewritten to call the script. Re-added `wtype` to `system/users/eksno/programs/default.nix` (it was dropped in the 2026-04-19 fix). `ydotool` stays for the Ctrl+V keystroke; Electron path uses both. Requires rebuild + Hyprland reload to pick up wtype and the new bind targets.
**Commit:** `32a8207`

**Follow-up (4a153e7):** Initial Electron path only worked when ALT was tap-released before the bind fired. Holding ALT while pressing a/o/e turned the synthesized paste into Ctrl+**Alt**+V, which Discord ignores. Script now injects release events for both Alts (56, 100) and both Shifts (42, 54) before sending Ctrl+V (29:1 47:1 47:0 29:0). The kernel/uinput state then matches what the paste keystroke needs even while the user keeps the modifier physically held. wtype path is unaffected — no synthesized chord, no modifier collision.

**Known limitation (4a153e7, unresolved):** The injected modifier-release isn't always enough — if ALT is held when the bind fires in an Electron app, Discord still occasionally treats the synthesized chord as Ctrl+Alt+V and drops it. Best theory: Hyprland keeps ALT in its xkb modifier mask for the duration of the bind dispatch and forwards that mask to the focused client alongside the injected key events, so Discord sees ALT-flagged Ctrl+V even though uinput says ALT is up. Tap-and-release ALT before pressing a/o/e is the practical workaround. Possible deeper fixes if this becomes annoying: (a) `sleep 0.05` between the modifier-release ydotool call and the Ctrl+V call to let Hyprland's modifier mask catch up; (b) move the bind to `bindr` (fires on key release) so the user's ALT is naturally lifting; (c) abandon the paste path entirely in favor of fcitx5/IBus for unicode entry. None deemed worth it for six binds.

## 2026-04-19 — norwegian-binds-wtype-electron-chromium

**Symptom:** `ALT+a/o/e` Hyprland binds (å/ø/æ via `wtype`) worked in Zen (Firefox) and native Wayland apps but silently did nothing in Discord, Beeper, Chrome — i.e. any Electron/Chromium client. Zen was the outlier, not the Electron apps.
**Affected:** verse/eksno, `dotfiles/default/hypr/users/eksno/default/norwegian.conf`, `system/users/eksno/default.nix`, `system/users/eksno/programs/default.nix`.
**Root cause:** `wtype` injects keystrokes via the Wayland `virtual_keyboard_unstable_v1` protocol. Firefox honors it; Chromium/Electron deliberately ignore it (their Ozone backend only accepts input-method-unstable-v2 or real HID events — assumed to be a hardening choice against headless keystroke spoofing). So there was nothing wrong with the binds, they just couldn't reach Electron surfaces. `NIXOS_OZONE_WL=1` is already set (Electron runs native Wayland, not XWayland), which rules out the usual "Electron is on XWayland" explanation and confirms the protocol-ignore behavior.
**Investigation:**
1. `grep -i discord` + `grep wtype` → found the binds in `norwegian.conf` and the `wtype` package in `programs/default.nix:144`. Confirmed setup is `wtype` (Wayland-only), US kb_layout, no compose key.
2. Checked `NIXOS_OZONE_WL=1` → set in `system/lib/desktop/wayland/default.nix:12`. Rules out the XWayland hypothesis — Electron is already running native Wayland. So the failure is at the protocol layer, not the display-server layer.
3. Options considered: (a) `ydotool` via `/dev/uinput` — bypasses Wayland protocols entirely, works in any app; (b) `wl-copy` + simulated `Ctrl+V` — zero setup but clobbers clipboard and breaks wherever Ctrl+V isn't paste. Picked (a).
4. Enabled `programs.ydotool.enable = true;`. First rebuild brought up `ydotoold.service` but the socket landed at `/run/ydotoold/socket` owned `root:ydotool` mode 0660, *not* the `$XDG_RUNTIME_DIR/.ydotool_socket` default ydotool looks for — so `ydotool` CLI errored with "failed to connect socket". Fix: add `eksno` to the `ydotool` group and set `environment.sessionVariables.YDOTOOL_SOCKET = "/run/ydotoold/socket";`.
5. Gotcha: group membership and `YDOTOOL_SOCKET` only take effect on new login sessions — the running Hyprland process inherits the old credentials, so binds will still fail until the user logs out and back in. `newgrp ydotool` activates the group for a subshell but won't help Hyprland itself.
6. Open risk not yet verified end-to-end: `ydotool type` sends raw keycodes via uinput, which the kernel then maps through the current xkb layout. On US layout, å/ø/æ have no native keycode — whether ydotool 1.0.4 does anything special (e.g. ctrl+shift+u unicode-entry in GTK, or KEY_UNKNOWN) is unconfirmed. If typing non-ASCII still fails after re-login, the fallback is `wl-copy $CHAR && ydotool key 29:1 47:1 47:0 29:0` (ctrl+v).
**Fix:** Swap `wtype` → `ydotool type` in `norwegian.conf`, enable `programs.ydotool.enable`, add `eksno` to `ydotool` group, set `YDOTOOL_SOCKET=/run/ydotoold/socket`, drop `wtype` from `programs/default.nix` (ydotool replaces it for this use case).
**Commit:** `979f810`

## 2026-04-19 — secure-askpass-age-ssh-agent-gate

**Symptom:** After the earlier `secure-askpass-silent-dialog-deny` fix, `sudo -A whoami` still failed with `Error: No password found in secure storage` even though `~/.sudo_askpass.age` existed and `age -d -i ~/.ssh/id_ed25519 ~/.sudo_askpass.age` at the shell printed the password fine.
**Affected:** verse/eksno, out-of-repo `~/.local/share/secure-askpass/askpass` (the GlassOnTin/secure-askpass `decrypt_with_age()` function). Surfaces on any host whose user has only a passphraseless key and no persistent ssh-agent holding it.
**Root cause:** `decrypt_with_age()` is unconditionally gated on `ensure_ssh_key_loaded()` before doing anything, and that helper fails for passphraseless keys. Flow: starts its own ssh-agent via `ssh-agent -s`, runs `ssh-add -l` (new agent → no keys loaded), doesn't match the key fingerprint, calls `prompt_ssh_passphrase()`. The user's ed25519 key was created with `-N ""` (empty passphrase), so the prompt returns an empty string, the helper treats that as "user cancelled" and returns `False`, and `decrypt_with_age` bails before ever invoking `age`. The SSH-key fallback (`decrypt_with_ssh_key`) then fails independently because `openssl pkeyutl -decrypt` in openssl 3.x can't read OpenSSH-format keys at all. Net result: both decrypt paths fail; the script prints "No password found" even though the file is right there.
**Investigation:**
1. Ran `sudo -A whoami` → `No password found in secure storage`. `ls ~/.sudo_askpass.*` confirmed `~/.sudo_askpass.age` (369 bytes, 600). So file exists; decrypt is failing.
2. Shell-level sanity check: `age -d -i ~/.ssh/id_ed25519 ~/.sudo_askpass.age` → printed the password. So age + key pair are correct — the script's wrapper is the problem.
3. Dead end: first assumed an openssl/format mismatch from the original `id_rsa` (OpenSSH format, passphrase-protected). Regenerated `id_ed25519 -N ""` and re-ran `askpass-manager set` — same failure, which ruled out the key format being the issue and pointed at the age wrapper itself.
4. Read `askpass:526-553` — saw the unconditional `ensure_ssh_key_loaded()` gate. Traced it to `askpass:425-475`: starts a fresh ssh-agent, finds the key unloaded, prompts for passphrase, gets empty, returns False. `age -d -i` doesn't actually need any agent when the key file is unencrypted, so the check is spurious for this setup.
5. Considered **NixOS-side fixes** (`programs.ssh.startAgent = true` + `exec-once = ssh-add ~/.ssh/id_ed25519` in hyprland startup.conf) so an agent with the key would be sitting there across sessions. Rejected: the eksno user's `programs.ssh.extraConfig` already points `IdentityAgent` at `~/.bitwarden-ssh-agent.sock` for git, and layering a second agent on top adds moving parts and depends on Hyprland starting before any sudo call — fragile. Also doesn't help non-Hyprland sessions (TTY, early-boot scripts).
**Fix:** Patched `~/.local/share/secure-askpass/askpass:526-553` locally to try `age -d -i SSH_KEY` **first**, and only fall back to `ensure_ssh_key_loaded()` + retry if that first attempt fails (i.e. the key is passphrase-encrypted and age genuinely needs the agent). Passphraseless keys now decrypt directly; passphrase-protected keys preserve the original behavior. Not committed to this repo — secure-askpass is cloned per-machine under `~/.local/share` and isn't nix-managed; `git pull` inside that clone will revert the patch. Re-applying is a two-line edit documented by this entry.
**Commit:** out-of-tree (patch lives in `~/.local/share/secure-askpass/askpass`)

## 2026-04-19 — secure-askpass-silent-dialog-deny

**Symptom:** `sudo -A whoami` (via Claude Code / non-TTY) exits with `Error: Security check failed` and syslog line `sudo-askpass[…]: User denied sudo access via dialog` — but **no dialog ever appeared on screen** for the user to click.
**Affected:** verse/eksno (any host/user invoking the out-of-repo secure-askpass at `/home/eksno/.local/share/secure-askpass/askpass`), `system/lib/desktop/default.nix`, `~/.local/share/secure-askpass/askpass-config.json`.
**Root cause:** `show_confirmation_dialog()` in the askpass script tries three GUI backends in order — tkinter, PyGObject/GTK, zenity — and on this box **all three are unavailable**: system `python3` ships without `_tkinter`, `gi` (PyGObject) isn't installed, and `zenity` isn't on PATH. Each branch raises/returns silently; the function falls through to `return False`. Because `DISPLAY` *is* set (Xwayland), the TOTP headless fallback is also skipped (`if 'DISPLAY' not in os.environ`). So askpass logs the misleading "User denied" message without ever rendering anything.
**Investigation:**
1. Ran `sudo -A whoami` with `SUDO_ASKPASS` sourced from `/etc/set-environment` — got `Security check failed` and no visible dialog.
2. `journalctl | grep askpass` showed `User denied sudo access via dialog` each run — initially assumed it was the user misclicking or the dialog appearing on the wrong monitor.
3. Traced `check_security()` → `show_confirmation_dialog()` in the askpass script. Noted the three GUI backends and the "DISPLAY set → skip TOTP" logic.
4. Probed each backend: `python3 -c 'import tkinter'` → `ModuleNotFoundError: _tkinter`; `python3 -c 'import gi'` → `ModuleNotFoundError`; `which zenity` → empty. Confirmed all three paths silently fail.
5. Dead end: briefly wondered if the dialog was rendering off-screen or behind other windows — ruled out once `HAS_GUI = False` was confirmed, since the tkinter branch is gated on that flag.
**Fix:** Two-layer fix so this works across the flake and not just eksno:
- `system/lib/desktop/default.nix`: add `zenity` and `(python3.withPackages (ps: [ ps.tkinter ]))` to `environment.systemPackages` so every desktop host has at least one working dialog backend. Put in the shared desktop module (not a per-user file) because any user that later opts into secure-askpass needs the same GUI fallbacks.
- `~/.local/share/secure-askpass/askpass-config.json`: set `require_user_confirmation: false`. Unblocks sudo immediately without a rebuild, and also means the GUI path is optional rather than a hard dependency. This file lives outside the repo (out-of-tree askpass clone) so it isn't tracked — document here.
Also note: `sudo -A` needs `SUDO_ASKPASS` in the caller's env. NixOS writes it via `environment.variables` → `/etc/set-environment` (bash/zsh-shaped), but **fish doesn't source that file**, so from a fish shell `sudo -A` fails with empty `SUDO_ASKPASS`. Not fixed here — separate concern — but logged so future-us doesn't re-diagnose.
**Commit:** `372dc27`

## 2026-04-17 — hypr-screenshot-mirror-logical-size

**Symptom:** `Super+v` screenshot on `lewis`/`jorge` captures the wrong region when the external HDMI-A-1 is mirroring the laptop. The PNG that lands on the clipboard shows content from the top-left of the screen instead of whatever the user actually selected — consistently offset, dimensions wrong.
**Affected:** host `lewis`, user `jorge`. `dotfiles/default/hypr/shared/scripts/screenshot-region.sh`. Provoked by the mirror config at `dotfiles/default/hypr/users/jorge/default/monitor.conf:5` (`eDP-1 2880x1800 @scale 1.25` mirroring `HDMI-A-1 1920x1080 @scale 1.0`).
**Root cause:** `eDP-1` (mirror) and `HDMI-A-1` (source) have **different logical sizes** (2304x1440 vs 1920x1080) but both live at `0x0`. When slurp reports `%X %Y` on the mirror, those coords are in the mirror's 2304x1440 logical space. Hyprland renders the source's 1920x1080 framebuffer _stretched_ to fill eDP-1's 2304x1440 logical space, so the mirror-to-source content mapping is proportional, not 1:1. The prior fix (hypr-screenshot-mirrored-output) followed the mirror chain to the right output and applied _the source's scale_, but skipped the mirror→source **logical-size remap**, so crops landed on the wrong HDMI pixels by factor `source_logical / mirror_logical` (≈0.83 horizontal, 0.75 vertical here).
**Investigation:**

1. Grepped FIXES.md — past entries ruled out slurp failing, wlr_screencopy on mirror, and scale-only fixes. Narrowed to coord transformation.
2. Dry-ran the script's pipeline with synthetic inputs — mirror chain resolved correctly, wayshot captured HDMI-A-1 as expected, but the magick crop coords were in mirror-logical space while the image was source-physical.
3. Briefly considered swapping to `grim -g "$(slurp)"` after testing showed grim working with HDMI connected — **dead end**. The moment HDMI disconnected (laptop-only, fractional scale 1.25), `grim` went back to `supplied geometry did not intersect with any outputs` and zero-width PNGs. `grimblast` too (it just wraps `grim -g`). The original 2026-04-07 fractional-scale bug is still live; grim only looked OK because the scale-1.0 HDMI output was temporarily present. wayshot + manual crop remains the only reliable primitive.
4. Verified that `hyprctl monitors all -j` emits enough info to compute both logical dimensions (`width/scale`, `height/scale`), so the remap can be data-driven rather than hardcoded.
5. Worked through the math: eDP-1 logical (1000, 600, 400, 40) should map to HDMI-A-1 physical (833, 450, 333, 30) — ratios 1920/2304 and 1080/1440. Confirmed with a synthetic awk run.
   **Fix:** In `screenshot-region.sh`, after the mirror-chain resolution, read the mirror's logical size and the source's logical size, remap `(X, Y, W, H)` from mirror-logical to source-logical via proportional scaling, **then** apply the source's scale for the physical crop. When `mirror == source` (no-mirror case) the ratios are 1.0 and the remap is a no-op, so laptop-only behavior is unchanged.
   **Commit:** `923f2d9`

## 2026-04-18 — hyprland-sddm-uwsm-session-unbootable

**Symptom:** Gens 99 and 100 on `verse` appeared stuck at the boot console after a prominent `Failed to start Name Service Cache Daemon (nsncd).` message; the desktop never came up. Gen 98 kept booting fine.
**Affected:** verse/eksno (and any host importing the shared Hyprland module: lewis/jorge, chuu/nabi, lappy/teto, chrono/teto), `system/lib/desktop/wayland/hyprland/default.nix:7-16`
**Root cause:** Two compounding bugs in the shared Hyprland module:

1. `services.displayManager.sddm.settings.Autologin.Session = "Hyprland"` — SDDM expects the `.desktop` filename, so autologin silently failed every boot (`Unable to find autologin session entry "Hyprland"`) and fell back to the greeter.
2. The Hyprland nixpkgs package ships both `hyprland.desktop` and `hyprland-uwsm.desktop`, but `programs.uwsm.enable` was never set, so the uwsm systemd --user units (`wayland-session-bindpid@.service`, etc.) weren't installed. When SDDM's last-session memory picked `hyprland-uwsm.desktop`, `uwsm start` died with `systemctl --user start wayland-session-bindpid@<pid>.service` exit 5 (unit not found). SDDM respawned without a working session — visually this looks like a hung boot console.

   **Investigation:**

3. Mistook `nscd.service: Start request repeated too quickly.` as the cause — spent time chasing the NSS target restart storm. Confirmed it was noise by observing the same cycle on the currently-working boot 0 (happens because every new NSS-dependent service re-evaluates `nss-{user-,}lookup.target`, cascading to nsncd).
4. Diffed SDDM session selection across boots: failed boots (-2, -3) both had `Session "...hyprland-uwsm.desktop" selected, command: ".../uwsm start -e -D Hyprland hyprland.desktop"`; working boot 0 had `hyprland.desktop` → `start-hyprland` directly.
5. Found `uwsm[…]: Command '['systemctl', '--user', 'start', 'wayland-session-bindpid@<pid>.service']' returned non-zero exit status 5` immediately before session death on failed boots. Grep of `system/` for `uwsm` returned zero hits, confirming the units were missing from the user unit path.
6. Also noticed `Autologin.Session = "Hyprland"` never matched a `.desktop` file — autologin has been silently broken the whole time, which is why the greeter (with its sticky last-session) was reached at all.
   **Fix:** In `system/lib/desktop/wayland/hyprland/default.nix`, set `programs.uwsm.enable = true;` (installs the uwsm user units so the uwsm session path works) and change `Autologin.Session = "Hyprland"` to `Autologin.Session = "hyprland.desktop"` (matches SDDM's lookup, restores autologin). Per-user `Autologin.User` was already set in each user's own config (`system/users/{eksno,jorge}/default.nix:29`).
   **Commit:** `<sha>`

**Investigation:**

1. Mistook `nscd.service: Start request repeated too quickly.` as the cause — spent time chasing the NSS target restart storm. Confirmed it was noise by observing the same cycle on the currently-working boot 0 (happens because every new NSS-dependent service re-evaluates `nss-{user-,}lookup.target`, cascading to nsncd).
2. Diffed SDDM session selection across boots: failed boots (-2, -3) both had `Session "...hyprland-uwsm.desktop" selected, command: ".../uwsm start -e -D Hyprland hyprland.desktop"`; working boot 0 had `hyprland.desktop` → `start-hyprland` directly.
3. Found `uwsm[…]: Command '['systemctl', '--user', 'start', 'wayland-session-bindpid@<pid>.service']' returned non-zero exit status 5` immediately before session death on failed boots. Grep of `system/` for `uwsm` returned zero hits, confirming the units were missing from the user unit path.
4. Also noticed `Autologin.Session = "Hyprland"` never matched a `.desktop` file — autologin has been silently broken the whole time, which is why the greeter (with its sticky last-session) was reached at all.
   **Fix:** In `system/lib/desktop/wayland/hyprland/default.nix`, set `programs.uwsm.enable = true;` (installs the uwsm user units so the uwsm session path works) and change `Autologin.Session = "Hyprland"` to `Autologin.Session = "hyprland.desktop"` (matches SDDM's lookup, restores autologin). Per-user `Autologin.User` was already set in each user's own config (`system/users/{eksno,jorge}/default.nix:29`).
   **Commit:** `edba39d`

## 2026-04-17 — mosh-restore-tab-quoting

**Symptom:** Mosh sessions not restored after tmux-resurrect restore. `restore-mosh.sh` exits silently with status 1 — pane gets default shell instead of reconnecting to the remote host.
**Affected:** all hosts/users with tmux-resurrect, `dotfiles/default/tmux/scripts/restore-mosh.sh:8`
**Root cause:** Single-quoted `\t` in `tmux display-message -p` format string. Bash single quotes prevent escape interpretation, and tmux itself doesn't interpret `\t` in format strings either. Result: `pane_id` contains literal `\t` characters (backslash + t) instead of tab characters. All downstream parameter expansion field splitting produces the full unsplit string for session/window/pane, awk matches nothing, `$host` is empty, script skips `exec mosh`.
**Investigation:**

1. `bash -x restore-mosh.sh` showed `pane_id='eksno\t5\t1'` with literal backslash-t — no actual tabs
2. Confirmed `session="${pane_id%%<TAB>*}"` found no tabs to split on, so session=window=pane=full string
3. Verified save file format uses real tab separators and awk field mapping ($2=session, $3=window, $6=pane, $11=command) is correct
4. Confirmed `setw -g pane-base-index 1` in tmux.conf means pane indices start at 1, matching save file
5. Script was created in `431eb4d` (2026-04-02) with the bug from day one — never worked. Renamed in `b772ef7` (2026-04-13), no logic change
   **Fix:** Changed single quotes to `$'...'` ANSI-C quoting on line 8 so `\t` becomes actual tab characters before being passed to tmux.
   **Commit:** `fd2c7c0`

## 2026-04-14 — hypr-screenshot-mirrored-output

**Symptom:** `Super+v` screenshot bind silently does nothing on `lewis`/`jorge` while the external HDMI monitor is mirroring the laptop display. Worked fine on single-output, also worked before when the external was extending rather than mirroring.
**Affected:** host `lewis`, user `jorge`. `dotfiles/default/hypr/shared/scripts/screenshot-region.sh`. Hyprland mirror config at `dotfiles/default/hypr/users/jorge/default/monitor.conf:5` (`monitor=eDP-1, ..., mirror, HDMI-A-1`).
**Root cause:** When a monitor is mirrored in Hyprland, the mirror source (here `eDP-1`) keeps its `wl_output` / `zxdg_output_v1` advertisement so slurp still reports it as the selection's output — but it is **not** exposed via `wlr-screencopy`, so `wayshot -o eDP-1` fails with `Error: No output found!`. The script captured slurp's output name verbatim and never checked whether it was a mirror, so `wayshot` errored out and the pipeline produced no PNG → nothing hit the clipboard.
**Investigation:**

1. Confirmed host/user/bind: `lewis`/`jorge`, `Super+v` → `screenshot-region.sh` (unchanged since `8ea8773`).
2. `hyprctl monitors` showed only `HDMI-A-1`; `hyprctl monitors all` revealed `eDP-1` with `mirrorOf: 1` — Hyprland hides mirror sources from the default listing but they're still present.
3. `wayshot -o eDP-1 /tmp/x.png` → `Error: No output found! at wayshot/src/wayshot.rs:237:17`. `wayshot -o HDMI-A-1 /tmp/y.png` → valid 156KB PNG. So the screencopy protocol view of outputs is narrower than the wl_output view.
4. Confirmed `hyprctl monitors all -j` emits `mirrorOf` as a _string_: `"none"` for a real output, or the numeric id (e.g. `"1"`) as a string when mirrored — so lookups need `(.id|tostring)==$id`.
   **Fix:** Added a mirror-resolution loop in `screenshot-region.sh` after the slurp read: if the output has `mirrorOf != "none"`, follow the chain via `hyprctl monitors all -j` to the real output before reading `scale` and running `wayshot -o`. Bounded at 3 hops as a paranoia cap. Scale is now read from the resolved output (mirror targets can have a different scale than the source). Logical coords from slurp stay valid because both outputs live at `0x0` in logical space.
   **Commit:** `a848b4a`

## 2026-04-13 — tpm-submodule-stale-section-name

**Symptom:** On jorge@lewis, TPM install binding (`prefix + I`) did nothing. Running `ctrl+a r` surfaced `'~/.config/tmux/plugins/tpm/tpm' returned 127` and `'~/.config/tmux/plugins/tmux/catppuccin.tmux' returned 127`. Git status also showed a mysterious staged `new file: dotfiles/tmux/plugins/tpm` at a path that no longer exists in the repo.
**Affected:** any fresh checkout, `.gitmodules`
**Root cause:** During the `b772ef72` default/ refactor, only the `path =` line in `.gitmodules` was updated; the `[submodule "dotfiles/tmux/plugins/tpm"]` section header was left at the old path. A plain `git pull` never populates submodules, and the stale section name caused git's submodule-to-path mapping to re-stage the submodule under the old `dotfiles/tmux/plugins/tpm` path on some checkouts. Empty `dotfiles/default/tmux/plugins/tpm/` → `run` line 127 → no `prefix+I` binding registered.
**Investigation:**

1. Assumed stale symlink — `readlink ~/.config/tmux` showed the correct default target, so that wasn't it
2. Assumed cached tmux server — `tmux kill-server` + fresh session didn't help
3. Assumed leftover override dir — `rm -rf dotfiles/users/jorge/tmux` + `./symlink.sh` fixed the symlink but not TPM
4. `ctrl+a r` reload revealed `returned 127` for both plugin run lines — pointed at missing files, not cached config
5. `git ls-files dotfiles/default/tmux/plugins/` showed a single entry with `git ls-tree HEAD` mode `160000` — a submodule, not a regular dir
6. `.gitmodules` section header still referenced `dotfiles/tmux/plugins/tpm` while `path =` was correct
   **Fix:** Renamed `.gitmodules` section header to `[submodule "dotfiles/default/tmux/plugins/tpm"]` and ran `git submodule sync`. Downstream users run `git submodule update --init --recursive` once to populate TPM; thereafter `prefix+I` works.
   **Commit:** `c5d991e`

## 2026-04-08 — meteor-lake-power-floor

**Symptom:** ~10W idle power draw on verse (ASUS UX3405MA, Core Ultra 7 155H) even at power-mode level 8/10 with nothing running. Advertised 19h battery life, getting ~5h.
**Affected:** verse/eksno, `system/lib/device/intel/default.nix`, `system/hosts/verse/default.nix`
**Root cause:** Meteor Lake architecture limits runtime package C-states to PC2 maximum. PC6-PC10 only occur during s2idle suspend. This is by design, not a bug. The 19h claim is from Windows where Intel's DTT driver does hardware-level coordination unavailable on Linux.
**Investigation:**

1. powertop showed package C2-C10 all at 0% — initially assumed this was a bug
2. `pmc_core/package_cstate_show` confirmed PC2 residency only
3. Checked PCI runtime PM — all devices `control=auto` but many active (iGPU, USB, WiFi, NVMe). These are expected since they're in use
4. Found both `i915` AND `xe` GPU drivers loaded simultaneously — blacklisted `xe`
5. Checked PSR status: PSR2 with selective fetch already active and working
6. Web research confirmed: PC2 is the architectural maximum during runtime on Meteor Lake. The ~7-8W floor is the SoC platform power (VRs, PCH, memory controller, eDP PHY) that can't be reduced from software
7. Applied kernel params (pcie_aspm=force, nmi_watchdog=0, snd_hda_intel/iwlwifi power_save, i915 fbc/dc=4), thermald, workload hints, TB wakeup disable. Marginal improvement at best
   **Fix:** No software fix possible for the platform power floor. Applied all available optimizations in `c0bf340`. Real improvement requires ASUS firmware updates or future kernel patches for Meteor Lake package C-state coordination.
   **Commit:** `c0bf340`

## 2026-04-08 — power-mode-boot-stale-level

**Symptom:** After reboot, waybar shows correct power-mode level (e.g. L8) but system draws 14W as if at level 0. Manually re-running `power-mode 8` fixes it.
**Affected:** verse/eksno, `system/lib/power-mode/default.nix`, `system/hosts/verse/default.nix`
**Root cause:** `/tmp` is not tmpfs on verse, so `/tmp/power-mode/current-level` survives reboot. The stateless watchdog reads current=8 from the stale file, sees target=8 (user-level), concludes no action needed. But sysfs settings (CPU freq, governor, RAPL, etc.) all reset to defaults on reboot.
**Investigation:**

1. Initially added a `power-mode-boot` systemd service — worked but added complexity
2. Refactored to stateless watchdog that determines target from user-level + battery state — simpler but same boot bug
3. Realized `/tmp` persistence was the root cause, not watchdog logic
   **Fix:** Added `systemd.tmpfiles.rules = [ "D /tmp/power-mode 1777 root root -" ]` to verse config. Clears the state dir on boot so the watchdog sees current=0 and re-applies the user's level.
   **Commit:** `c0bf340`

---

## 2026-04-07 — hypr-screenshot-fractional-scaling

**Symptom:** `Super+v` screenshot bind silently does nothing on the laptop's built-in display (`eDP-1`), but works fine when an external monitor is connected and used. Initial "fix" with `grimblast copy area` advertised `image/png` on the clipboard but the data was 0 bytes — pasted as nothing.
**Affected:** host `lewis`, user `jorge`. `dotfiles/hypr/shared/workflow/default/binds/qwerty.conf:15`. eDP-1 runs at scale **1.25** (2880x1800 physical, 2304x1440 logical). Hyprland 0.54.2.
**Root cause:** On Hyprland 0.54.x with fractional scaling, the entire grim toolchain is broken: `grim` returns "supplied geometry did not intersect with any outputs" for any region or output target, and even bare `grim FILE` produces a zero-width PNG (`libpng warning: Image width is zero in IHDR`). `grimblast` is just a wrapper around `grim` so it inherits the bug. `wayshot` has a separate bug in its region/all-outputs paths (`wp_viewport: Size was <= 0`, Protocol error 1) that only manifests when no specific output is targeted. The only path that actually works is `wayshot -o <output-name>` which captures a single output at physical pixel resolution. External monitors at scale 1.0 dodged the grim bug, which is why the bind appeared to "only work on the external display".
**Investigation:**

1. Confirmed active host/user: `lewis` / `jorge`. Active keymap: `qwerty.conf` (sourced from `dotfiles/hypr/users/jorge/default.conf:3`). eDP-1 at scale 1.25 via `hyprctl monitors`.
2. Found bind: `bind = $mainMod, v, exec, sh -c 'grim -g "$(slurp)" - | wl-copy'`.
3. Reproduced grim failure directly: `grim -o eDP-1 /tmp/test.png` → `supplied geometry did not intersect with any outputs`. Not a slurp issue.
4. **First attempted fix (wrong):** switched bind to `grimblast copy area`. The package list comment in `system/users/jorge/programs/default.nix:163` claimed grimblast "handles fractional scaling" — this was misleading. Test proved it false: `grimblast save output /tmp/foo.png` failed with the exact same grim error because grimblast just shells out to `grim -t png -o eDP-1 /tmp/foo.png`. Clipboard advertised `image/png` but `wl-paste --type image/png` returned 0 bytes — the wl-copy received empty stdin from grim's failed run.
5. Tried `wayshot -o eDP-1 /tmp/test.png` — produced a valid 412KB PNG with proper `\x89PNG` magic. Wayshot with explicit output works.
6. Tried `wayshot --clipboard /tmp/foo.png` (no `-o`) — failed with `Failed to encode PNG: Zero width not allowed`. Default-all-outputs mode is also broken under fractional scaling.
7. Tried `wayshot -g --clipboard` and `wayshot --geometry "0,0 200x200" --clipboard` — both failed with `wp_viewport: Size was <= 0` / Protocol error 1 at `wayshot/src/wayshot.rs:180`. Wayshot's region path is broken regardless of how the geometry is supplied. Confirmed via subagent research against waycrate/wayshot README that the canonical invocation `wayshot -g "$(slurp)" --clipboard` is the documented one — it's just incompatible with Hyprland 0.54.2's `wp_viewport` implementation.
8. Verified `wayshot -o eDP-1 --clipboard /tmp/foo.png` works end-to-end: file written, clipboard contains valid PNG (`wl-paste --type image/png` returns the 671KB data). Output-targeted wayshot is the only reliable primitive.
9. Checked Wayland protocols via `nix run nixpkgs#wayland-utils` — both legacy `zwlr_screencopy_manager_v1 v3` and new `ext_image_copy_capture_manager_v1` are advertised. Wayshot's `-o` path probably uses the new protocol; grim only speaks the legacy one and the Hyprland bug lives there.
10. **Final approach:** since only `wayshot -o NAME` works, capture the entire selected output at physical resolution and crop in software. slurp's `%X %Y %w %h %o` format gives output-relative logical coords plus the output name; multiply by the output's `scale` from `hyprctl monitors -j` to convert logical → physical pixels, then `magick - -crop "${PW}x${PH}+${PX}+${PY}"` does the crop. ImageMagick was already in the system package list (`system/users/jorge/programs/default.nix:113`).
    **Fix:** Created `dotfiles/hypr/shared/scripts/screenshot-region.sh` implementing the slurp → wayshot → magick → wl-copy pipeline (works because the entire `dotfiles/hypr/shared/` tree is already symlinked into `~/.config/hypr/shared/` by `symlink.sh`). Updated `dotfiles/hypr/shared/workflow/default/binds/qwerty.conf:15` to invoke that script. Reloaded with `./hypr.sh`. The same broken pattern still exists in `dvp.conf:19`, `dvp.conf:22`, `voyager1H.conf:11`, `voyager2H.conf:21`, and `voyager2H-old.conf:11` for other users — left untouched per scope. The misleading "handles fractional scaling" comment on `grimblast` in `system/users/jorge/programs/default.nix:163` should probably be corrected in a follow-up.
    **Commit:** `533693c` (initial broken grimblast attempt), `8ea8773` (working wayshot+magick wrapper)
