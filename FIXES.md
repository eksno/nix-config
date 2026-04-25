# Fixes Log

Chronological log of non-trivial fixes for this NixOS flake. Newest entries at the top. See `CLAUDE.md` "Log Every Fix" section for the entry format and rules.

**Before debugging a new issue, grep this file first** — a past investigation may contain the answer.

## 2026-04-25 — tmux-restore-mosh-script-not-symlinked

**Symptom:** `~/.config/tmux/scripts/restore-mosh.sh` not found; tmux-resurrect couldn't restore mosh-client panes after the dotfiles activation-script migration.
**Affected:** verse/eksno, `system/lib/dotfiles.nix:73`, references from `dotfiles/default/tmux/tmux.conf:70` (`@resurrect-processes`).
**Root cause:** The 2026-04-19 migration from `symlink.sh` to `system/lib/dotfiles.nix` switched tmux from a directory symlink to file-level symlinks (because TPM writes into `plugins/`). The new block only linked `tmux.conf` and `tmux-nerd-font-window-name.yml`, dropping the `scripts/` subdirectory. `restore-mosh.sh` lived in the repo but was never deployed to `~/.config/tmux/`, so resurrect's exec path resolved to nothing.
**Investigation:**
1. `ls ~/.config/tmux/` → only `tmux.conf` + yml symlinks + `plugins/`. No `scripts/`. Repo path `dotfiles/default/tmux/scripts/restore-mosh.sh` exists and is executable, so the file isn't lost — just unlinked.
2. Read `system/lib/dotfiles.nix` tmux block → confirmed the activation script only `ln -sf`s the two known files. No glob, no scripts dir.
3. Considered switching tmux back to a full directory symlink. Rejected: TPM still needs to write into `plugins/`, which is the whole reason file-level symlinks were chosen. Cleanest fix is one extra `ln -sfn` for `scripts/` since it's a read-only dir of executables.
**Fix:** Added `ln -sfn "$_src/scripts" "$cfg/tmux/scripts"` to the tmux block in `system/lib/dotfiles.nix`. After `./update.sh`, `~/.config/tmux/scripts → nix-config/dotfiles/default/tmux/scripts` and resurrect can find `restore-mosh.sh`.
**Commit:** `<pending>`

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
