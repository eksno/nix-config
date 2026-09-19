import contextlib
import io
import json
import subprocess
from unittest.mock import patch
from pathlib import Path
import tempfile
import unittest

import policy


class RulesTests(unittest.TestCase):
    def test_defaults_only_notify(self):
        self.assertEqual(policy.parse_rules(policy.DEFAULT_RULES), [(25, "notif"), (10, "notif")])

    def test_examples_and_boundaries(self):
        self.assertEqual(len(policy.parse_rules("75:notif,50:L5,25:L9,10:notif")), 4)
        self.assertEqual(policy.parse_rules("100:L0,1:L9"), [(100, "L0"), (1, "L9")])
        self.assertEqual(len(policy.parse_rules("50:L5,25:L5")), 2)

    def test_reject_ambiguous_and_unsafe_input(self):
        for value in ["", "0:notif", "101:notif", "-1:L1", "01:L1", "50:save",
                      "50:L10", "50:L-1", "50:l5", "50:Notif", "50", "50:",
                      "50:L5,75:L9", "50:L5,50:notif", "50:L5,", ",50:L5",
                      "50:L5,,25:L9", "50:L5  ", " 50:L5", "50:L5\n", "50:L5;id",
                      "50:L5,$(id)", "50:L5, 25:L9", "５０:L5", "50:L5\x00"]:
            with self.subTest(value=value), self.assertRaises(ValueError):
                policy.parse_rules(value)


class PlanningTests(unittest.TestCase):
    def step(self, text, percent, manual=3, override=None, state=None, discharging=True):
        return policy.plan(policy.parse_rules(text), percent, discharging, manual, override, state or {})

    def test_default_never_changes_manual_level(self):
        state = {}
        for percent, expected in [(80, []), (25, [(25, "notif")]), (24, []),
                                  (10, [(10, "notif")]), (0, [])]:
            target, notices, state = self.step(policy.DEFAULT_RULES, percent, state=state)
            self.assertEqual(target, 3)
            self.assertEqual(notices, expected)

    def test_ladder_and_notification_only_step(self):
        text = "75:notif,50:L5,25:L9,10:notif"
        state = {}
        for percent, expected in [(100, 3), (75, 3), (50, 5), (25, 9), (10, 9)]:
            target, _, state = self.step(text, percent, state=state)
            self.assertEqual(target, expected)

    def test_manual_override_survives_thresholds_and_plugging(self):
        text = "75:L5,25:L9"
        state = {}
        for percent, discharging in [(80, True), (50, True), (20, True), (20, False), (20, True)]:
            target, _, state = self.step(text, percent, override=2, state=state, discharging=discharging)
            self.assertEqual(target, 2)
        # After reboot, the override and watchdog state are absent.
        self.assertEqual(self.step(text, 20)[0], 9)

    def test_reboot_selects_current_band_without_manual_override(self):
        self.assertEqual(self.step("75:L5,25:L9", 40, manual=8)[0], 5)
        self.assertEqual(self.step("75:L5,25:L9", 90, manual=8)[0], 8)

    def test_percentage_noise_does_not_repeat_or_reverse_actions(self):
        _, _, state = self.step("50:L5", 50)
        target, notices, state = self.step("50:L5", 51, state=state)
        self.assertEqual((target, notices), (5, []))
        self.assertEqual(self.step("50:L5", 50, state=state)[1], [])

    def test_charge_resets_notifications_and_restores_manual(self):
        _, _, state = self.step("50:L5", 30)
        target, notices, state = self.step("50:L5", 30, state=state, discharging=False)
        self.assertEqual((target, notices), (3, []))
        self.assertEqual(self.step("50:L5", 30, state=state)[1], [(50, "L5")])

    def test_changed_configuration_is_evaluated(self):
        _, _, state = self.step("50:notif", 30)
        self.assertEqual(self.step("50:L5", 30, state=state)[:2], (5, [(50, "L5")]))

    def test_level_zero_is_an_automatic_action(self):
        self.assertEqual(self.step("100:L0", 80)[0], 0)

    def test_invalid_battery_reading_fails(self):
        for percent in [-1, 101]:
            with self.assertRaises(ValueError):
                self.step(policy.DEFAULT_RULES, percent)


class PersistenceTests(unittest.TestCase):
    def setUp(self):
        self.directory = tempfile.TemporaryDirectory()
        self.old_data, self.old_runtime = policy.DATA, policy.RUNTIME
        policy.DATA = Path(self.directory.name) / "data"
        policy.RUNTIME = Path(self.directory.name) / "run"

    def tearDown(self):
        policy.DATA, policy.RUNTIME = self.old_data, self.old_runtime
        self.directory.cleanup()

    def configure(self, text):
        with contextlib.redirect_stdout(io.StringIO()):
            policy.configure(text)

    def test_rejected_config_preserves_rules_and_override(self):
        self.configure("50:L5")
        policy.remember_manual(9)
        with self.assertRaises(ValueError):
            self.configure("25:L9,50:L5")
        self.assertEqual(policy.read_rules()[0], "50:L5")
        self.assertEqual(policy.read_level(policy.RUNTIME / "manual-override"), 9)

    def test_without_ladder_manual_level_is_durable(self):
        policy.remember_manual(8)
        self.assertEqual(policy.read_level(policy.DATA / "user-level"), 8)
        self.assertEqual(policy.read_level(policy.RUNTIME / "manual-override"), 8)

    def test_ladder_override_does_not_replace_durable_baseline(self):
        policy.remember_manual(3)
        self.configure("50:L5")
        self.assertFalse((policy.RUNTIME / "manual-override").exists())
        policy.remember_manual(9)
        self.assertEqual(policy.read_level(policy.DATA / "user-level"), 3)
        self.assertEqual(policy.read_level(policy.RUNTIME / "manual-override"), 9)

    def test_corrupt_saved_level_is_not_silently_used(self):
        policy.atomic_write(policy.DATA / "user-level", "12\n")
        with self.assertRaises(ValueError):
            policy.read_level(policy.DATA / "user-level")


class WatchdogTests(PersistenceTests):
    def setUp(self):
        super().setUp()
        root = Path(self.directory.name)
        self.state = root / "session" / "power-mode-watchdog.json"
        supply = root / "power_supply"
        battery = supply / "BAT0"
        battery.mkdir(parents=True)
        (battery / "energy_now").write_text("10000000")
        (battery / "capacity").write_text("20")
        (battery / "status").write_text("Discharging")
        self.patches = [patch.object(policy, "POWER_SUPPLY", supply),
                        patch.object(policy, "CURRENT", root / "current-level"),
                        patch.dict(policy.os.environ, {"XDG_RUNTIME_DIR": str(self.state.parent)})]
        for replacement in self.patches:
            replacement.start()
        self.commands = []
        self.failure = None
        self.runner = patch.object(policy.subprocess, "run", side_effect=self.run_command)
        self.runner.start()

    def tearDown(self):
        self.runner.stop()
        for replacement in reversed(self.patches):
            replacement.stop()
        super().tearDown()

    def run_command(self, args, check):
        self.commands.append(args)
        if args[0] not in ("power-mode-test", "notify-test"):
            self.fail(f"Unexpected external command: {args}")
        if args[0] == "power-mode-test":
            code = self.failure or 0
            if not code:
                policy.atomic_write(policy.CURRENT, args[2])
        else:
            code = 1 if self.failure == "notification" else 0
        result = subprocess.CompletedProcess(args, code)
        if check:
            result.check_returncode()
        return result

    def tick(self):
        policy.tick("power-mode-test", "notify-test")

    def test_reapply_on_boot_even_if_current_file_survived(self):
        policy.atomic_write(policy.DATA / "user-level", "8")
        policy.atomic_write(policy.CURRENT, "8")
        self.tick()
        self.assertEqual(self.commands[0], ["power-mode-test", "--auto", "8"])
        self.commands.clear()
        self.tick()
        self.assertEqual(self.commands, [])

    def test_failure_does_not_claim_success_or_consume_notification(self):
        self.configure("25:L9")
        self.failure = 1
        with self.assertRaises(subprocess.CalledProcessError):
            self.tick()
        self.assertFalse(self.state.exists())
        self.assertFalse(any(c[0] == "notify-test" for c in self.commands))
        self.failure = None
        self.tick()
        self.assertEqual(json.loads(self.state.read_text())["seen"], [25])

    def test_concurrent_manual_selection_wins(self):
        self.configure("25:L9")
        self.failure = 75
        self.tick()
        self.assertFalse(self.state.exists())
        self.assertEqual(len(self.commands), 1)

    def test_notification_failure_is_retried(self):
        self.failure = "notification"
        policy.remember_manual(3)
        policy.atomic_write(policy.CURRENT, "3")
        with self.assertRaises(subprocess.CalledProcessError):
            self.tick()
        self.assertFalse(self.state.exists())
        self.failure = None
        self.tick()
        self.assertTrue(self.state.exists())
        self.assertTrue(all(c[0] == "notify-test" for c in self.commands))

    def test_notification_only_threshold_does_not_call_hardware(self):
        policy.remember_manual(6)
        policy.atomic_write(policy.CURRENT, "6")
        self.tick()
        self.assertEqual(len(self.commands), 1)
        self.assertEqual(self.commands[0][0], "notify-test")

    def test_manual_override_during_ladder_still_notifies(self):
        self.configure("25:L9")
        policy.remember_manual(2)
        policy.atomic_write(policy.CURRENT, "2")
        self.tick()
        self.assertEqual(len(self.commands), 1)
        self.assertIn("Manual level L2 remains", self.commands[0][-1])


if __name__ == "__main__":
    unittest.main()
