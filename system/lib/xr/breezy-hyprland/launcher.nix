{
  writeShellApplication,
  systemd,
  monadoRayneo,
  wayvr,
}:

# Single-command entry point: tear down xr-driver (it holds /dev/hidrawN
# locks Monado needs), start monado-service in the background, wait for
# the OpenXR socket to appear, then run WayVR in the foreground.
#
# On exit (Ctrl-C, glasses unplugged, wayvr crash), kill monado and
# bring xr-driver back so the system returns to its baseline.
writeShellApplication {
  name = "breezy-hyprland";
  runtimeInputs = [
    systemd
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

    cleanup() {
      [[ -n ''${MONADO_PID:-} ]] && kill "$MONADO_PID" 2>/dev/null || true
      # Reap the `sleep infinity` that's keeping monado's stdin open.
      pkill -P $$ -x sleep 2>/dev/null || true
      systemctl --user start xr-driver 2>/dev/null || true
    }
    trap cleanup EXIT INT TERM

    LOG="''${XDG_RUNTIME_DIR}/monado-service.log"

    echo "[breezy-hyprland] stopping xr-driver to release HID locks"
    systemctl --user stop xr-driver

    # Clear stale lock from a previous failed start; otherwise monado-service
    # refuses to launch with "another instance is running."
    rm -f "''${XDG_RUNTIME_DIR}/monado.pid"

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
    exec wayvr --openxr --show
  '';
}
