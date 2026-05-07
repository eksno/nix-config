{
  writeShellApplication,
  systemd,
  hyprland,
  jq,
  monadoRayneo,
  wayvr,
}:

# Single-command entry point: tear down xr-driver (it holds /dev/hidrawN
# locks Monado needs), start monado-service in the background, wait for
# the OpenXR socket to appear, then run WayVR in the foreground.
#
# On exit (Ctrl-C, glasses unplugged, wayvr crash), SIGINT monado and
# wait for it to release the lease, restore the Hyprland monitor as a
# safety net, and bring xr-driver back.
#
# NOTE on direct DRM mode (Phase 3 status, 2026-05-06):
#   We previously thought `hyprctl keyword monitor desc:..., disable`
#   would release the connector for monado to take a direct DRM lease.
#   It doesn't — wlroots only advertises NON-DESKTOP outputs via
#   wp-drm-lease-v1, and the Rayneo EDID doesn't set that bit.
#   See xr/LEARNINGS.md "wlroots only leases non-desktop outputs" and
#   xr/plans/03-... Phase 3 for the EDID-override path that's needed.
writeShellApplication {
  name = "breezy-hyprland";
  runtimeInputs = [
    systemd
    hyprland
    jq
    monadoRayneo
    wayvr
  ];
  text = ''
    set -euo pipefail

    # Point the OpenXR loader at our patched Monado. We also set this in
    # environment.variables, but that only takes effect on next login —
    # setting it here means breezy-hyprland works on first install without
    # a relogin. Path is fixed by the nix store hash of monadoRayneo so
    # /nix/var rebuilds invalidate it correctly.
    export XR_RUNTIME_JSON="${monadoRayneo}/share/openxr/1/openxr_monado.json"

    # Glasses' EDID-derived Hyprland identity. Used as a safety net in the
    # cleanup trap — if anything ever ends up disabling the output, this
    # restores it to the user's baseline (mirror of HDMI-A-1, matching
    # dotfiles/.../jorge/default/monitor.conf:10). The mirror clause is a
    # no-op when HDMI-A-1 is absent.
    GLASSES_BASELINE="desc:Technical Concepts Ltd SmartGlasses, 1920x1080@120, auto, 1, mirror, HDMI-A-1"

    # Phase 4A — per-workspace virtual screens.
    # Spawn N headless wl_outputs and move workspaces 1..N onto them, so
    # WayVR sees N+1 screens at startup (laptop + N workspaces) and we get
    # one independent capture per workspace. N=4 default; override with
    # BREEZY_N_SCREENS=K. Set BREEZY_N_SCREENS=0 to disable and keep the
    # legacy single-screen behavior.
    BREEZY_N_SCREENS=''${BREEZY_N_SCREENS:-4}
    HEADLESS_OUTPUTS=()

    cleanup() {
      if [[ -n ''${MONADO_PID:-} ]]; then
        # SIGINT, not SIGTERM/SIGKILL: monado needs to release its DRM
        # resources and IPC socket cleanly. Abrupt teardown leaves the
        # connector half-leased and trashes Hyprland's monitor list
        # (saved as feedback memory after a 2026-05-05 incident).
        kill -INT "$MONADO_PID" 2>/dev/null || true
        for _ in $(seq 1 100); do
          kill -0 "$MONADO_PID" 2>/dev/null || break
          sleep 0.1
        done
        # Escalate only if SIGINT was ignored for 10s.
        kill "$MONADO_PID" 2>/dev/null || true
      fi
      # Reap the `sleep infinity` that's keeping monado's stdin open.
      pkill -P $$ -x sleep 2>/dev/null || true
      # Remove headless outputs AFTER monado/wayvr exit, so they don't
      # disappear under wayvr mid-frame.
      for out in "''${HEADLESS_OUTPUTS[@]:-}"; do
        [[ -n "$out" ]] && hyprctl output remove "$out" >/dev/null 2>&1 || true
      done
      hyprctl keyword monitor "$GLASSES_BASELINE" >/dev/null 2>&1 || true
      systemctl --user start xr-driver 2>/dev/null || true
    }
    trap cleanup EXIT INT TERM

    LOG="''${XDG_RUNTIME_DIR}/monado-service.log"

    echo "[breezy-hyprland] stopping xr-driver to release HID locks"
    systemctl --user stop xr-driver

    # Clear stale lock from a previous failed start; otherwise monado-service
    # refuses to launch with "another instance is running."
    rm -f "''${XDG_RUNTIME_DIR}/monado.pid"

    # Clear stale IPC socket from a previous run. Without this, the wait
    # loop below sees the OLD socket file, breaks immediately, and launches
    # wayvr before monado-service has finished init. Monado then removes
    # the stale socket and creates its own — but wayvr already failed to
    # connect with "Connection refused" and exits clean, taking monado
    # down with it before any frame is presented. Verified 2026-05-06.
    rm -f "''${XDG_RUNTIME_DIR}/monado_comp_ipc"

    if [[ "$BREEZY_N_SCREENS" -gt 0 ]]; then
      echo "[breezy-hyprland] creating $BREEZY_N_SCREENS headless outputs"
      # hyprctl output create returns the assigned name on stdout in the
      # form "ok\n" — we have to discover the new monitor by diffing
      # `hyprctl monitors -j` before/after.
      for _ in $(seq 1 "$BREEZY_N_SCREENS"); do
        # `.[].name` walks the top-level array (monitors only), avoiding
        # the nested `activeWorkspace.name` field which `grep "name"`
        # would also match.
        BEFORE=$(hyprctl monitors -j | jq -r '.[].name' | sort -u)
        hyprctl output create headless >/dev/null
        # Hyprland needs a tick to register the new output.
        sleep 0.2
        AFTER=$(hyprctl monitors -j | jq -r '.[].name' | sort -u)
        NEW=$(comm -13 <(echo "$BEFORE") <(echo "$AFTER") | head -1)
        if [[ -n "$NEW" ]]; then
          HEADLESS_OUTPUTS+=("$NEW")
          echo "[breezy-hyprland]   spawned $NEW"
        else
          echo "[breezy-hyprland]   warning: failed to detect new headless output" >&2
        fi
      done
      # Move workspaces 1..N onto the headless outputs we just made.
      # Workspace 0 doesn't exist in Hyprland; ws 1 stays on the laptop
      # (eDP-1) since that's the user's primary surface. Ws 2..N+1 go
      # onto HEADLESS-2..HEADLESS-(N+1) one-to-one.
      for i in "''${!HEADLESS_OUTPUTS[@]}"; do
        WS=$((i + 2))
        OUT="''${HEADLESS_OUTPUTS[$i]}"
        # Make sure the workspace exists before moving it. Empty
        # workspaces aren't created until first focus; force creation by
        # focusing then immediately moving.
        hyprctl dispatch workspace "$WS" >/dev/null 2>&1 || true
        hyprctl dispatch moveworkspacetomonitor "$WS $OUT" >/dev/null 2>&1 || true
      done
      # Return focus to workspace 1 so the user starts on the laptop.
      hyprctl dispatch workspace 1 >/dev/null 2>&1 || true
    fi

    echo "[breezy-hyprland] starting monado-service in background (log: $LOG)"
    # Stdin needs to be a pipe that stays open forever. The full constraint:
    #   - TTY:        epoll_ctl(stdin) returns -1 → init failure
    #   - /dev/null:  same — char devices don't implement poll()
    #   - true|:      pipe is pollable, but `true` exits immediately and
    #                 monado interprets the resulting EOF as "parent died,
    #                 time to shut down" (clean exit right after Vulkan init)
    #   - sleep inf|: pollable + never EOFs → monado stays running ✓
    # The sleep child is in this script's process group, so the EXIT trap
    # (which kills MONADO_PID) leaves it as a zombie until shell exit;
    # explicitly pkill it to be tidy.
    sleep infinity | monado-service > "$LOG" 2>&1 &
    MONADO_PID=$!

    # Monado opens its OpenXR IPC socket on $XDG_RUNTIME_DIR/monado_comp_ipc
    # once compositor init finishes. Vulkan device creation on Intel Arc can
    # take a few seconds — spin up to 15s.
    SOCK="''${XDG_RUNTIME_DIR}/monado_comp_ipc"
    for _ in $(seq 1 150); do
      [[ -S "$SOCK" ]] && break
      # Short-circuit: if monado already died, stop waiting.
      if ! kill -0 "$MONADO_PID" 2>/dev/null; then
        echo "[breezy-hyprland] monado-service exited before opening socket — last log lines:" >&2
        tail -20 "$LOG" >&2 || true
        exit 1
      fi
      sleep 0.1
    done
    if [[ ! -S "$SOCK" ]]; then
      echo "[breezy-hyprland] monado-service did not open $SOCK in 15s — last log lines:" >&2
      tail -20 "$LOG" >&2 || true
      exit 1
    fi

    echo "[breezy-hyprland] launching wayvr"
    # Do NOT exec — that replaces the shell process and kills the EXIT
    # trap, leaving us no way to clean up monado/xr-driver on exit.
    wayvr --openxr --show
  '';
}
