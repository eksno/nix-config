{
  writeShellApplication,
  glib,
  gnome-shell,
  coreutils,
  procps,
  breezyGnome,
}:

# Wrapper that launches a nested `gnome-shell --wayland` with the breezy-gnome
# extension enabled, so head-tracked virtual surfaces world-lock inside a
# Hyprland window. Reads pose from /dev/shm/breezy_desktop_imu (written by
# the xr-driver running in `output_mode=external_only`).
#
# Toggle behavior: a PID file in $XDG_RUNTIME_DIR/breezy-sideview tracks the
# active instance. Re-running `breezy-sideview --toggle` while it's up sends
# SIGTERM to the existing wrapper, which traps and cleans up the child shell.
#
# Settings isolation: a private dconf profile (user-db:breezy-sideview) keeps
# the extension's gsettings out of the host user's dconf db. The host's
# `org.gnome.shell enabled-extensions` is untouched — important for users who
# also boot a real GNOME session elsewhere (e.g. eksno on verse).
writeShellApplication {
  name = "breezy-sideview";
  runtimeInputs = [
    glib
    gnome-shell
    coreutils
    procps
  ];
  text = ''
    # --- Arg parsing ---
    preset="2-screen"
    toggle=false
    while [[ $# -gt 0 ]]; do
      case "$1" in
        --preset) preset="$2"; shift 2 ;;
        --toggle) toggle=true; shift ;;
        --no-toggle) toggle=false; shift ;;
        -h|--help)
          cat <<HLP
    Usage: breezy-sideview [--toggle] [--preset 2-screen]

    Launches a nested GNOME shell hosting world-locked XR surfaces.
    --toggle: if a prior instance is running, terminate it and exit.
    --preset: 2-screen (default). 3-screen is reserved for a follow-up
              once upstream exposes a virtual-display-count schema key.
    HLP
          exit 0 ;;
        *) echo "breezy-sideview: unknown arg: $1" >&2; exit 2 ;;
      esac
    done

    case "$preset" in
      2-screen) ;;
      3-screen)
        echo "breezy-sideview: --preset 3-screen unsupported (schema lacks virtual-display-count); using 2-screen" >&2
        preset="2-screen"
        ;;
      *) echo "breezy-sideview: unknown preset: $preset" >&2; exit 2 ;;
    esac

    : "''${XDG_RUNTIME_DIR:?XDG_RUNTIME_DIR must be set}"
    runtime_dir="''${XDG_RUNTIME_DIR}/breezy-sideview"
    mkdir -p "''${runtime_dir}"
    pid_file="''${runtime_dir}/instance.pid"

    # --- Toggle: kill prior instance and exit ---
    if [[ "''${toggle}" == "true" && -f "''${pid_file}" ]]; then
      prev_pid="$(cat "''${pid_file}" 2>/dev/null || true)"
      if [[ -n "''${prev_pid}" ]] && kill -0 "''${prev_pid}" 2>/dev/null; then
        kill -TERM "''${prev_pid}"
        echo "breezy-sideview: stopped pid=''${prev_pid}" >&2
        exit 0
      fi
      rm -f "''${pid_file}"
    fi

    # --- Cleanup ---
    shell_pid=""
    cleanup() {
      [[ -n "''${shell_pid}" ]] && kill -0 "''${shell_pid}" 2>/dev/null && kill -TERM "''${shell_pid}" 2>/dev/null || true
      rm -f "''${pid_file}"
    }
    trap cleanup EXIT INT TERM

    echo "$$" > "''${pid_file}"

    # --- Plumb schemas for our gsettings calls ---
    # nixpkgs installs gnome-shell schemas at
    # share/gsettings-schemas/gnome-shell-<ver>/glib-2.0/schemas/ rather
    # than share/glib-2.0/schemas/, so XDG_DATA_DIRS alone doesn't reach
    # them. The breezy-gnome extension's schema is even further off-path
    # (share/gnome-shell/extensions/.../schemas/). GSETTINGS_SCHEMA_DIR
    # takes a colon list of compiled-schema dirs and is honored directly
    # by gsettings/dconf.
    export GSETTINGS_SCHEMA_DIR="${gnome-shell}/share/gsettings-schemas/gnome-shell-${gnome-shell.version}/glib-2.0/schemas:${breezyGnome}/share/gnome-shell/extensions/breezydesktop@xronlinux.com/schemas"

    # XDG_DATA_DIRS still needs the breezy-gnome share/ so the nested shell
    # discovers the extension under share/gnome-shell/extensions/.
    export XDG_DATA_DIRS="${breezyGnome}/share''${XDG_DATA_DIRS:+:''${XDG_DATA_DIRS}}"

    # --- Isolated dconf profile ---
    # `user-db:breezy-sideview` resolves to ~/.config/dconf/breezy-sideview,
    # so the host user's primary `~/.config/dconf/user` stays untouched.
    profile="''${runtime_dir}/dconf-profile"
    printf 'user-db:breezy-sideview\n' > "''${profile}"
    export DCONF_PROFILE="''${profile}"

    gsettings set org.gnome.shell enabled-extensions "['breezydesktop@xronlinux.com']"
    case "''${preset}" in
      2-screen)
        gsettings set com.xronlinux.BreezyDesktop display-distance 1.05
        gsettings set com.xronlinux.BreezyDesktop display-size 1.0
        gsettings set com.xronlinux.BreezyDesktop curved-display false
        gsettings set com.xronlinux.BreezyDesktop widescreen-mode false
        ;;
    esac

    # Match Air 4 Pro native glasses res. mutter doesn't expose multi-monitor
    # specs in nested mode, so a single 1920x1080 surface is what gnome-shell
    # will drive — breezy-gnome itself wraps it into virtual-display layout.
    export MUTTER_DEBUG_DUMMY_MODE_SPECS="1920x1080@60"

    gnome-shell --nested --wayland &
    shell_pid="$!"
    wait "''${shell_pid}"
  '';
}
