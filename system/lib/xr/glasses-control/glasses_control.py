#!/usr/bin/env python3
"""Cockpit — control panel for the Rayneo XR session.

A top-down view of where your virtual screens sit around you, the
handful of controls worth reaching for while wearing the glasses, and
live telemetry underneath.

Since wayvr captures the desktop, this window is usable from inside the
headset.

Screen positions and head pose come from wayvrctl (screen-list /
screen-place / input-state), which needs the ipc-telemetry-and-layout
patch in system/lib/xr/wayvr-anv.
"""

import json
import math
import os
import subprocess
import time
from dataclasses import dataclass, field

import gi

gi.require_version("Gtk", "4.0")
gi.require_version("Adw", "1")
from gi.repository import Adw, Gdk, GLib, Gtk  # noqa: E402

UNIT = "glasses-vr"
# The .scratch test harness runs under its own unit; treat either as
# "the session is up" until the launcher graduates out of .scratch.
LEGACY_UNIT = "wayvr-test"
SESSION_SCRIPT = os.environ.get(
    "GLASSES_VR_SCRIPT",
    "/home/jorge/nix-config/.scratch/xr-reboot/wayvr-visual-test.sh",
)
SUPERVISOR_LOG = os.environ.get(
    "GLASSES_VR_LOG",
    "/home/jorge/nix-config/.scratch/xr-reboot/wayvr-test-supervisor.log",
)
MONADO_LOG = os.environ.get(
    "GLASSES_MONADO_LOG",
    "/home/jorge/nix-config/.scratch/xr-reboot/monado-test.log",
)
WAYVRCTL = os.environ.get("WAYVRCTL", "wayvrctl")
PANEL_SYSFS = "/sys/class/drm/card1-DP-2/enabled"

# Layout is re-read every LAYOUT_EVERY ticks; it only changes when
# something moves a screen, and each read costs a wayvrctl round trip.
TICK_MS = 500
LAYOUT_EVERY = 4
# Slider drags coalesce into one screen-place this many ms after the
# last change.
SETTLE_MS = 180

CSS = b"""
window, .cockpit { background: #0a0f0d; }
.panel { background: #0e1512; border: 1px solid #1c2a24; border-radius: 12px; }
.accent { color: #46e6a0; }
.muted { color: #63796f; }
.metric-label { color: #63796f; font-size: 10px; letter-spacing: 1.4px; }
.metric-value { color: #d7efe5; font-size: 22px; font-family: monospace; }
.metric-value.good { color: #46e6a0; }
.metric-value.warn { color: #e6c246; }
.metric-value.bad { color: #e6685a; }
.headline { color: #d7efe5; font-size: 14px; font-weight: 600; }
.sublabel { color: #63796f; font-size: 11px; font-family: monospace; }
.rowitem {
  background: #131c18; border: 1px solid #1c2a24; border-radius: 8px;
  padding: 8px 12px;
}
.rowitem.sel { background: #12362a; border-color: #1f5c48; }
.dot { font-size: 9px; }
.dot.live { color: #46e6a0; }
.dot.off { color: #3c4a43; }
button.act {
  background: #12362a; color: #46e6a0; border: 1px solid #1f5c48;
  border-radius: 8px; padding: 8px 16px; font-weight: 600;
}
button.act:hover { background: #174535; }
button.ghost {
  background: #131c18; color: #9fbfb2; border: 1px solid #1c2a24;
  border-radius: 8px; padding: 8px 16px;
}
"""


def run(argv, timeout=10):
    try:
        return subprocess.run(argv, capture_output=True, text=True, timeout=timeout)
    except (OSError, subprocess.SubprocessError) as e:
        return subprocess.CompletedProcess(argv, 1, "", str(e))


def wayvrctl_json(*args, timeout=4):
    """wayvrctl prints one line of compact JSON on stdout; logs go to stderr."""
    r = run([WAYVRCTL, *args], timeout=timeout)
    if r.returncode != 0:
        return None
    for line in r.stdout.splitlines():
        line = line.strip()
        if line.startswith(("{", "[")):
            try:
                return json.loads(line)
            except json.JSONDecodeError:
                return None
    return None


def process_running(name):
    """Match on the executable name only. -f would also match any shell
    whose command line happens to mention the path."""
    return run(["pgrep", "-x", name], timeout=4).returncode == 0


def unit_active(unit):
    return run(["systemctl", "--user", "is-active", unit], timeout=4).stdout.strip() == "active"


def read_file(path):
    try:
        with open(path) as f:
            return f.read().strip()
    except OSError:
        return ""


def cpu_temp():
    for hw in sorted(os.listdir("/sys/class/hwmon")):
        base = f"/sys/class/hwmon/{hw}"
        if read_file(f"{base}/name") == "coretemp":
            raw = read_file(f"{base}/temp1_input")
            if raw.isdigit():
                return int(raw) / 1000.0
    return None


def quat_to_yaw_pitch(q):
    """Degrees the headset is turned/tilted, from an (x, y, z, w) quaternion.

    Derived from the rotated forward vector rather than an euler
    decomposition, so head roll doesn't leak into the readout.
    """
    x, y, z, w = q
    # forward = q * (0, 0, -1)
    fx = -2.0 * (x * z + w * y)
    fy = -2.0 * (y * z - w * x)
    fz = -(1.0 - 2.0 * (x * x + y * y))
    yaw = math.degrees(math.atan2(fx, -fz))
    pitch = math.degrees(math.asin(max(-1.0, min(1.0, fy))))
    return yaw, pitch


@dataclass
class Screen:
    """One screen overlay, in the units the sidebar speaks."""

    name: str
    yaw: float = 0.0          # degrees around you, + is right
    pitch: float = 0.0        # degrees of elevation
    distance: float = 0.6     # metres
    width: float = 0.8        # metres across
    curvature: float = 0.0    # percent of a full circle (wayvr caps at 50)
    visible: bool = True

    @classmethod
    def from_ipc(cls, d):
        return cls(
            name=d["name"],
            yaw=d["yaw"],
            pitch=d["pitch"],
            distance=d["distance"],
            width=d["scale"],
            curvature=d["curvature"] * 100.0,
            visible=d["visible"],
        )


@dataclass
class Telemetry:
    running: bool = False
    panel: bool = False
    monado: bool = False
    phase: str = ""
    fps: float | None = None
    dropped: float | None = None
    yaw: float | None = None
    pitch: float | None = None
    temp: float | None = None
    screens: list | None = field(default=None)


class Poller:
    def __init__(self):
        self._miss_mark = (0, time.monotonic())

    def missed_per_sec(self):
        try:
            with open(MONADO_LOG, "rb") as f:
                count = f.read().count(b"missed frame")
        except OSError:
            return None
        prev_count, prev_t = self._miss_mark
        now = time.monotonic()
        dt = now - prev_t
        if dt < 1.0:
            return None
        self._miss_mark = (count, now)
        if prev_count == 0:
            return None
        return max(0.0, (count - prev_count) / dt)

    def phase(self):
        try:
            with open(SUPERVISOR_LOG) as f:
                lines = [ln.strip() for ln in f if ln.startswith("[test]")]
        except OSError:
            return ""
        if not lines:
            return ""
        line = lines[-1].removeprefix("[test]").strip()
        for noisy in ("step 0:", "step 1:", "step 2a:", "step 2c:", "step 3", "step 4:"):
            line = line.removeprefix(noisy).strip()
        return line[:64]

    def poll(self, want_layout):
        t = Telemetry()
        t.monado = process_running("monado-service")
        t.running = process_running("wayvr")
        t.panel = read_file(PANEL_SYSFS) == "enabled"
        t.phase = self.phase()
        t.temp = cpu_temp()
        t.dropped = self.missed_per_sec() if t.running else None

        if not t.running:
            return t

        state = wayvrctl_json("input-state")
        if state:
            t.fps = state.get("fps")
            rot = state.get("hmd_rot")
            if rot and len(rot) == 4:
                t.yaw, t.pitch = quat_to_yaw_pitch(rot)

        if want_layout:
            screens = wayvrctl_json("screen-list")
            if screens is not None:
                t.screens = [Screen.from_ipc(s) for s in screens]
        return t


class Radar(Gtk.DrawingArea):
    """Top-down map: you at the centre, screens arranged around you."""

    def __init__(self):
        super().__init__(hexpand=True, vexpand=True)
        self.screens: list[Screen] = []
        self.selected = 0
        self.yaw = 0.0
        self.set_draw_func(self.draw)

    def draw(self, _area, cr, width, height):
        cx, cy = width / 2, height * 0.66
        max_r = min(width * 0.42, height * 0.52)

        cr.set_source_rgb(0.039, 0.059, 0.051)
        cr.paint()

        for frac in (0.35, 0.62, 0.9):
            cr.set_source_rgba(0.27, 0.42, 0.36, 0.28)
            cr.set_line_width(1)
            cr.arc(cx, cy, max_r * frac, math.pi, 2 * math.pi)
            cr.stroke()

        cr.set_source_rgba(0.27, 0.42, 0.36, 0.18)
        cr.move_to(cx, cy)
        cr.line_to(cx, cy - max_r)
        cr.stroke()

        # viewer cone, rotated by live head yaw
        cr.save()
        cr.translate(cx, cy)
        cr.rotate(math.radians(self.yaw or 0.0))
        cr.set_source_rgba(0.27, 0.90, 0.63, 0.22)
        cr.move_to(0, 0)
        cr.line_to(-max_r * 0.30, -max_r * 0.42)
        cr.line_to(max_r * 0.30, -max_r * 0.42)
        cr.close_path()
        cr.fill()
        cr.restore()

        cr.set_source_rgb(0.84, 0.94, 0.90)
        cr.arc(cx, cy, 5, 0, 2 * math.pi)
        cr.fill()

        for i, s in enumerate(self.screens):
            theta = math.radians(s.yaw)
            reach = 0.3 + min(s.distance, 3.0) / 3.0 * 0.6
            r = max_r * reach
            px, py = cx + r * math.sin(theta), cy - r * math.cos(theta)
            half = max_r * 0.20 * min(s.width, 3.0)

            sel = i == self.selected
            if not s.visible:
                cr.set_source_rgba(0.35, 0.42, 0.39, 0.5)
            elif sel:
                cr.set_source_rgb(0.27, 0.90, 0.63)
            else:
                cr.set_source_rgb(0.44, 0.53, 0.49)

            cr.set_line_width(6 if sel else 4)
            cr.set_line_cap(1)
            cr.save()
            cr.translate(px, py)
            cr.rotate(theta)
            cr.move_to(-half, 0)
            cr.line_to(half, 0)
            cr.stroke()
            cr.restore()

            cr.select_font_face("monospace")
            cr.set_font_size(11)
            label = f"{s.name} · {s.yaw:+.0f}°"
            ext = cr.text_extents(label)
            cr.set_source_rgba(0.84, 0.94, 0.90, 1.0 if sel else 0.55)
            cr.move_to(px - ext.width / 2, py - 16 if py < cy else py + 24)
            cr.show_text(label)


class Metric(Gtk.Box):
    def __init__(self, label):
        super().__init__(orientation=Gtk.Orientation.VERTICAL, spacing=4,
                         hexpand=True, margin_top=10, margin_bottom=10,
                         margin_start=14, margin_end=14)
        self.title = Gtk.Label(label=label, xalign=0, css_classes=["metric-label"])
        self.value = Gtk.Label(label="—", xalign=0, css_classes=["metric-value"])
        self.append(self.title)
        self.append(self.value)

    def set(self, text, quality=None):
        self.value.set_label(text)
        self.value.set_css_classes(["metric-value"] + ([quality] if quality else []))


# key, label, min, max, step, suffix, decimals
SLIDERS = (
    ("yaw", "Angle", -180.0, 180.0, 1.0, "°", 0),
    ("width", "Screen size", 0.3, 3.0, 0.05, " m", 2),
    ("distance", "Distance", 0.3, 3.0, 0.05, " m", 2),
    ("curvature", "Curvature", 0.0, 50.0, 1.0, "%", 0),
    ("pitch", "Pitch", -45.0, 45.0, 1.0, "°", 0),
)


class Window(Adw.ApplicationWindow):
    def __init__(self, app):
        super().__init__(application=app, title="Cockpit",
                         default_width=1080, default_height=680)
        self.poller = Poller()
        self.screens: list[Screen] = []
        self.selected = 0
        self.busy_until = 0.0
        self.ticks = 0
        # Set while the sliders are written to from telemetry, so the
        # resulting value-changed signals don't echo back as edits.
        self.syncing = False
        self.settle_source = None

        self.toast = Adw.ToastOverlay()
        outer = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, css_classes=["cockpit"])
        outer.append(self._header())

        split = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL, spacing=12,
                        margin_start=12, margin_end=12, margin_bottom=12,
                        vexpand=True)
        left = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=12, hexpand=True)
        self.radar = Radar()
        radar_frame = Gtk.Box(css_classes=["panel"], vexpand=True)
        radar_frame.append(self.radar)
        left.append(radar_frame)
        left.append(self._metrics())
        split.append(left)
        split.append(self._sidebar())
        outer.append(split)

        self.toast.set_child(outer)
        self.set_content(self.toast)

        provider = Gtk.CssProvider()
        provider.load_from_data(CSS)
        Gtk.StyleContext.add_provider_for_display(
            Gdk.Display.get_default(), provider,
            Gtk.STYLE_PROVIDER_PRIORITY_APPLICATION)

        self.sync_sliders()
        self.tick()
        GLib.timeout_add(TICK_MS, self.tick)

    # ---- layout ----------------------------------------------------

    def _header(self):
        bar = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL, spacing=10,
                      margin_top=12, margin_bottom=12,
                      margin_start=16, margin_end=16)
        self.dot = Gtk.Label(label="●", css_classes=["dot", "off"])
        self.state_label = Gtk.Label(label="VR mode off", css_classes=["headline"])
        self.sub_label = Gtk.Label(label="", css_classes=["sublabel"])
        bar.append(self.dot)
        bar.append(self.state_label)
        bar.append(self.sub_label)
        bar.append(Gtk.Box(hexpand=True))

        self.power_btn = Gtk.Button(label="Turn on", css_classes=["act"])
        self.power_btn.connect("clicked", self.on_power)
        self.recenter_btn = Gtk.Button(label="Recenter", css_classes=["act"])
        self.recenter_btn.connect("clicked", self.on_recenter)
        bar.append(self.power_btn)
        bar.append(self.recenter_btn)
        return bar

    def _metrics(self):
        strip = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL, spacing=1,
                        css_classes=["panel"], homogeneous=True)
        self.metrics = {}
        for key, label in (("fps", "FPS"), ("dropped", "DROPPED/S"),
                           ("yaw", "YAW"), ("pitch", "PITCH"), ("temp", "CPU TEMP")):
            m = Metric(label)
            self.metrics[key] = m
            strip.append(m)
        return strip

    def _sidebar(self):
        side = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=12,
                       width_request=300, css_classes=["panel"])
        inner = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=10,
                        margin_top=16, margin_bottom=16,
                        margin_start=14, margin_end=14)

        inner.append(Gtk.Label(label="DISPLAYS", xalign=0, css_classes=["metric-label"]))
        self.display_list = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=6)
        inner.append(self.display_list)

        inner.append(Gtk.Separator(margin_top=6, margin_bottom=6))

        self.sliders = {}
        for key, label, lo, hi, step, unit, decimals in SLIDERS:
            row = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=2)
            head = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL)
            head.append(Gtk.Label(label=label, xalign=0, css_classes=["muted"]))
            head.append(Gtk.Box(hexpand=True))
            val = Gtk.Label(label="—", css_classes=["sublabel"])
            head.append(val)
            scale = Gtk.Scale.new_with_range(Gtk.Orientation.HORIZONTAL, lo, hi, step)
            scale.set_draw_value(False)
            scale.connect("value-changed", self.on_slider, key)
            row.append(head)
            row.append(scale)
            inner.append(row)
            self.sliders[key] = (scale, val, unit, decimals)

        side.append(inner)
        return side

    def rebuild_displays(self):
        child = self.display_list.get_first_child()
        while child:
            nxt = child.get_next_sibling()
            self.display_list.remove(child)
            child = nxt

        for i, s in enumerate(self.screens):
            row = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL, spacing=8,
                          css_classes=["rowitem"] + (["sel"] if i == self.selected else []))
            row.append(Gtk.Label(label=s.name, xalign=0,
                                 css_classes=["accent"] if i == self.selected else []))
            row.append(Gtk.Box(hexpand=True))
            row.append(Gtk.Label(label=f"{s.yaw:+.0f}°", css_classes=["sublabel"]))
            click = Gtk.GestureClick()
            click.connect("released", self.on_select, i)
            row.add_controller(click)
            self.display_list.append(row)

    def sync_sliders(self):
        self.syncing = True
        try:
            has = bool(self.screens)
            s = self.screens[self.selected] if has else None
            for key, (scale, val, unit, decimals) in self.sliders.items():
                scale.set_sensitive(has)
                if not has:
                    val.set_label("—")
                    continue
                value = getattr(s, key)
                scale.set_value(value)
                val.set_label(f"{value:.{decimals}f}{unit}")
        finally:
            self.syncing = False

    # ---- events ----------------------------------------------------

    def on_select(self, _gesture, _n, _x, _y, index):
        self.selected = index
        self.radar.selected = index
        self.rebuild_displays()
        self.sync_sliders()
        self.radar.queue_draw()

    def on_slider(self, scale, key):
        if self.syncing or not self.screens:
            return
        value = scale.get_value()
        setattr(self.screens[self.selected], key, value)

        _, val, unit, decimals = self.sliders[key]
        val.set_label(f"{value:.{decimals}f}{unit}")
        self.radar.queue_draw()

        # Coalesce a drag into a single screen-place.
        if self.settle_source:
            GLib.source_remove(self.settle_source)
        self.settle_source = GLib.timeout_add(SETTLE_MS, self.flush_placement)

    def flush_placement(self):
        self.settle_source = None
        if not self.screens:
            return False
        s = self.screens[self.selected]
        r = run([WAYVRCTL, "screen-place", s.name,
                 "--yaw", f"{s.yaw:.3f}",
                 "--pitch", f"{s.pitch:.3f}",
                 "--distance", f"{s.distance:.3f}",
                 "--scale", f"{s.width:.3f}",
                 "--curvature", f"{s.curvature / 100.0:.4f}"], timeout=6)
        if r.returncode != 0:
            self.notify(f"Could not move {s.name}")
        return False

    def notify(self, text):
        self.toast.add_toast(Adw.Toast(title=text, timeout=3))

    def on_power(self, _btn):
        if self.session_up():
            self.busy_until = time.monotonic() + 14
            run(["systemctl", "--user", "stop", UNIT], timeout=20)
            run(["systemctl", "--user", "stop", LEGACY_UNIT], timeout=20)
            self.notify("VR mode off")
        else:
            run(["systemctl", "--user", "reset-failed", UNIT], timeout=5)
            r = run(["systemd-run", "--user", f"--unit={UNIT}", "--collect",
                     "--setenv=LIFETIME=86400", "bash", SESSION_SCRIPT], timeout=15)
            if r.returncode != 0:
                self.notify("Could not start: " + (r.stderr or "").strip()[:60])

    @staticmethod
    def session_up():
        return (process_running("monado-service")
                or unit_active(UNIT) or unit_active(LEGACY_UNIT))

    def on_recenter(self, _btn):
        r = run([WAYVRCTL, "recenter"], timeout=6)
        self.notify("Recentered" if r.returncode == 0 else "Recenter failed")

    # ---- refresh ---------------------------------------------------

    def tick(self):
        self.ticks += 1
        # Don't re-read the layout mid-drag; it would fight the sliders.
        want_layout = self.ticks % LAYOUT_EVERY == 0 and self.settle_source is None
        t = self.poller.poll(want_layout)
        live = t.running and t.monado

        if time.monotonic() < self.busy_until:
            state, sub = "Stopping…", t.phase
        elif live:
            state, sub = "Tracking locked", "3DoF · world-locked"
        elif self.session_up():
            state, sub = "Starting…", t.phase
        else:
            state, sub = "VR mode off", "glasses mirror the desktop"

        self.state_label.set_label(state)
        self.sub_label.set_label(sub)
        self.dot.set_css_classes(["dot", "live" if live else "off"])
        self.power_btn.set_label("Turn off" if self.session_up() else "Turn on")
        self.recenter_btn.set_sensitive(live)

        self.metrics["fps"].set(
            f"{t.fps:.0f}" if t.fps else "—",
            "good" if t.fps and t.fps >= 55 else "warn" if t.fps else None)
        self.metrics["dropped"].set(
            f"{t.dropped:.0f}" if t.dropped is not None else "—",
            "good" if t.dropped == 0 else "warn" if t.dropped else None)
        self.metrics["yaw"].set(f"{t.yaw:+.1f}°" if t.yaw is not None else "—")
        self.metrics["pitch"].set(f"{t.pitch:+.1f}°" if t.pitch is not None else "—")
        self.metrics["temp"].set(
            f"{t.temp:.1f} °C" if t.temp else "—",
            "bad" if t.temp and t.temp > 90 else "warn" if t.temp and t.temp > 75 else "good")

        self.apply_layout(t.screens if live else [])

        self.radar.yaw = t.yaw or 0.0
        self.radar.queue_draw()
        return True

    def apply_layout(self, screens):
        """Adopt the session's layout, including moves made from inside
        the headset. `None` means it wasn't read this tick."""
        if screens is None:
            return
        names_changed = [s.name for s in screens] != [s.name for s in self.screens]
        self.screens = screens
        self.selected = min(self.selected, max(0, len(screens) - 1))
        self.radar.screens = screens
        self.radar.selected = self.selected
        if names_changed:
            self.rebuild_displays()
        self.sync_sliders()


class App(Adw.Application):
    def __init__(self):
        super().__init__(application_id="no.starti.Cockpit")

    def do_activate(self):
        win = self.props.active_window or Window(self)
        win.present()


if __name__ == "__main__":
    Adw.StyleManager.get_default().set_color_scheme(Adw.ColorScheme.FORCE_DARK)
    App().run(None)
