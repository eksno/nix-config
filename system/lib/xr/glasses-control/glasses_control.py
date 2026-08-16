#!/usr/bin/env python3
"""Glasses — a small control panel for the Rayneo XR session.

Start/stop VR mode, recenter the world, and choose whether the head
drives the pointer. Everything else (screen layout, capture) lives in
wayvr's own config; this window is deliberately the short list of
things you touch while wearing the glasses.

Because wayvr captures the desktop, this window is visible inside the
headset too.
"""

import os
import subprocess

import gi

gi.require_version("Gtk", "4.0")
gi.require_version("Adw", "1")
from gi.repository import Adw, GLib, Gtk  # noqa: E402

UNIT = "glasses-vr"
SESSION_SCRIPT = os.environ.get(
    "GLASSES_VR_SCRIPT",
    "/home/jorge/nix-config/.scratch/xr-reboot/wayvr-visual-test.sh",
)
SUPERVISOR_LOG = os.environ.get(
    "GLASSES_VR_LOG",
    "/home/jorge/nix-config/.scratch/xr-reboot/wayvr-test-supervisor.log",
)
WAYVRCTL = os.environ.get("WAYVRCTL", "wayvrctl")
PANEL_SYSFS = "/sys/class/drm/card1-DP-2/enabled"


def run(argv, **kw):
    try:
        return subprocess.run(argv, capture_output=True, text=True, timeout=15, **kw)
    except (OSError, subprocess.SubprocessError) as e:
        return subprocess.CompletedProcess(argv, 1, "", str(e))


def pgrep(pattern):
    return run(["pgrep", "-f", pattern]).returncode == 0


def unit_active(unit):
    return run(["systemctl", "--user", "is-active", unit]).stdout.strip() == "active"


def panel_lit():
    try:
        with open(PANEL_SYSFS) as f:
            return f.read().strip() == "enabled"
    except OSError:
        return False


def last_phase():
    """Most recent '[test] ...' line, cleaned up for humans."""
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
    return line[:70]


class Window(Adw.ApplicationWindow):
    def __init__(self, app):
        super().__init__(application=app, title="Glasses",
                         default_width=380, default_height=520)

        self.toast = Adw.ToastOverlay()
        root = Gtk.Box(orientation=Gtk.Orientation.VERTICAL)
        root.append(Adw.HeaderBar(title_widget=Adw.WindowTitle(title="Glasses")))

        body = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=18,
                       margin_top=18, margin_bottom=18,
                       margin_start=18, margin_end=18)

        self.state_label = Gtk.Label(css_classes=["title-1"])
        self.phase_label = Gtk.Label(css_classes=["dim-label"], wrap=True,
                                     justify=Gtk.Justification.CENTER)
        status_card = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=6,
                              css_classes=["card"], margin_bottom=2,
                              margin_top=6)
        inner = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=6,
                        margin_top=22, margin_bottom=22,
                        margin_start=12, margin_end=12)
        inner.append(self.state_label)
        inner.append(self.phase_label)
        status_card.append(inner)
        body.append(status_card)

        self.power_btn = Gtk.Button(css_classes=["pill", "suggested-action"],
                                    height_request=48)
        self.power_btn.connect("clicked", self.on_power)
        body.append(self.power_btn)

        self.recenter_btn = Gtk.Button(label="Recenter", height_request=48,
                                       css_classes=["pill"])
        self.recenter_btn.connect("clicked", self.on_recenter)
        body.append(self.recenter_btn)

        group = Adw.PreferencesGroup()
        self.head_row = Adw.SwitchRow(
            title="Head pointer",
            subtitle="Move the cursor by looking around")
        self.head_row.set_active(False)
        self.head_row.connect("notify::active", self.on_head_pointer)
        group.add(self.head_row)
        body.append(group)

        detail = Adw.PreferencesGroup(title="Status")
        self.rows = {}
        for key, title in (("monado", "Tracking runtime"),
                           ("wayvr", "Screens"),
                           ("panel", "Glasses display")):
            row = Adw.ActionRow(title=title)
            icon = Gtk.Image()
            row.add_suffix(icon)
            self.rows[key] = (row, icon)
            detail.add(row)
        body.append(detail)

        root.append(body)
        self.toast.set_child(root)
        self.set_content(self.toast)

        self.busy = False
        self.refresh()
        GLib.timeout_add_seconds(1, self.refresh)

    # ---- state -----------------------------------------------------

    def running(self):
        return pgrep("result-wayvr/bin/wayvr") or unit_active(UNIT)

    def starting(self):
        return (unit_active(UNIT) or unit_active("wayvr-test")) and not self.running()

    def refresh(self):
        monado = pgrep("monado-service")
        wayvr = pgrep("result-wayvr/bin/wayvr")
        lit = panel_lit()
        live = wayvr and lit

        if self.busy:
            state, phase = "Working…", last_phase()
        elif live:
            state, phase = "VR mode on", "Screens are world-locked"
        elif monado or unit_active(UNIT):
            state, phase = "Starting…", last_phase()
        else:
            state, phase = "VR mode off", "Glasses mirror the desktop"

        self.state_label.set_label(state)
        self.phase_label.set_label(phase)

        on = monado or unit_active(UNIT)
        self.power_btn.set_label("Turn off" if on else "Turn on")
        self.power_btn.set_css_classes(
            ["pill", "destructive-action" if on else "suggested-action"])
        self.power_btn.set_sensitive(not self.busy)
        self.recenter_btn.set_sensitive(live and not self.busy)
        self.head_row.set_sensitive(live)

        for key, ok in (("monado", monado), ("wayvr", wayvr), ("panel", lit)):
            row, icon = self.rows[key]
            icon.set_from_icon_name(
                "emblem-ok-symbolic" if ok else "radio-symbolic")
            icon.set_css_classes(["success"] if ok else ["dim-label"])
        return True

    # ---- actions ---------------------------------------------------

    def notify(self, text):
        self.toast.add_toast(Adw.Toast(title=text, timeout=3))

    def on_power(self, _btn):
        if pgrep("monado-service") or unit_active(UNIT):
            self.busy = True
            self.refresh()
            run(["systemctl", "--user", "stop", UNIT])
            run(["systemctl", "--user", "stop", "wayvr-test"])
            GLib.timeout_add_seconds(14, self.done, "VR mode off")
        else:
            run(["systemctl", "--user", "reset-failed", UNIT])
            r = run(["systemd-run", "--user", f"--unit={UNIT}", "--collect",
                     "--setenv=LIFETIME=86400", "bash", SESSION_SCRIPT])
            if r.returncode != 0:
                self.notify("Could not start: " + (r.stderr or "").strip()[:60])
            self.refresh()

    def done(self, message):
        self.busy = False
        self.notify(message)
        self.refresh()
        return False

    def on_recenter(self, _btn):
        r = run([WAYVRCTL, "recenter"])
        self.notify("Recentered" if r.returncode == 0 else "Recenter failed")

    def on_head_pointer(self, row, _param):
        mode = "hmd" if row.get_active() else "none"
        r = run([WAYVRCTL, "handsfree", "set-mode", mode])
        if r.returncode != 0:
            self.notify("Could not change pointer mode")


class App(Adw.Application):
    def __init__(self):
        super().__init__(application_id="no.starti.Glasses")

    def do_activate(self):
        win = self.props.active_window or Window(self)
        win.present()


if __name__ == "__main__":
    App().run(None)
