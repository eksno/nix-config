import contextlib
import io
from pathlib import Path
import subprocess
import tempfile
import unittest
from unittest.mock import patch

import cli
import policy


class CliTests(unittest.TestCase):
    def run_cli(self, args):
        output, errors = io.StringIO(), io.StringIO()
        with contextlib.redirect_stdout(output), contextlib.redirect_stderr(errors):
            status = cli.dispatch(args, "power-mode-test")
        return status, output.getvalue(), errors.getvalue()

    def test_help_never_reads_state_or_runs_privileged_commands(self):
        with patch.object(Path, "read_text", side_effect=AssertionError("Help read state")), \
             patch.object(subprocess, "run", side_effect=AssertionError("Help ran a command")):
            for args in [[], ["-h"], ["--help"], ["help"], ["help", "configure"],
                         ["configure", "--help"], ["configure", "bad-input", "-h"],
                         ["status", "--help"], ["5", "--help"], ["config", "-h"],
                         ["calibrate", "-h"], ["stretch", "--help"], ["charge-limit", "-h"]]:
                with self.subTest(args=args):
                    status, output, errors = self.run_cli(args)
                    self.assertEqual(status, 0)
                    self.assertTrue(output)
                    self.assertEqual(errors, "")

    def test_invalid_arguments_stop_before_privilege(self):
        for args in [["unknown"], ["5", "extra"], ["status", "extra"], ["configure", "a", "b"],
                     ["stretch"], ["stretch", "0"], ["stretch", "1;id"], ["charge-limit", "101"]]:
            with self.subTest(args=args):
                status, _, errors = self.run_cli(args)
                self.assertEqual(status, 2)
                self.assertIn("power-mode", errors)

    def test_valid_mutations_continue_to_hardware_wrapper(self):
        for args in [["5"], ["status"], ["calibrate"], ["stretch", "4.5"],
                     ["charge-limit"], ["charge-limit", "80"], ["configure", "25:notif,10:notif"]]:
            self.assertEqual(self.run_cli(args)[0], cli.CONTINUE)

    def test_validation_identifies_the_fault(self):
        for rules, expected in [("50:L5,50:notif", "threshold 50 appears twice"),
                                ("25:L9,50:L5", "threshold 50 follows 25"),
                                ("50:save", "action 'save' is invalid"),
                                ("101:notif", "percentage '101' is invalid")]:
            status, output, errors = self.run_cli(["configure", rules])
            self.assertEqual((status, output), (2, ""))
            self.assertIn(expected, errors)
            self.assertIn("configuration is unchanged", errors)

    def test_prompt_requires_terminal(self):
        with patch.object(cli.sys.stdin, "isatty", return_value=False):
            status, _, errors = self.run_cli(["configure"])
        self.assertEqual(status, 2)
        self.assertIn("Supply rules as an argument", errors)

    def test_prompt_retries_then_passes_exact_valid_input(self):
        with patch.object(cli.sys.stdin, "isatty", return_value=True), \
             patch.object(policy, "read_rules", return_value=(policy.DEFAULT_RULES, [])), \
             patch("builtins.input", side_effect=["25:L9,50:L5", "50:L5,25:L9"]), \
             patch.object(subprocess, "run", return_value=subprocess.CompletedProcess([], 0)) as run:
            status, output, errors = self.run_cli(["configure"])
        self.assertEqual(status, 0)
        self.assertIn("notif only notifies", output)
        self.assertIn("descending order", errors)
        run.assert_called_once_with(["power-mode-test", "configure", "50:L5,25:L9"], check=False)

    def test_prompt_cancellation_does_not_save(self):
        for reply, expected in [("", 0), (KeyboardInterrupt(), 130), (EOFError(), 130)]:
            with patch.object(cli.sys.stdin, "isatty", return_value=True), \
                 patch.object(policy, "read_rules", return_value=(policy.DEFAULT_RULES, [])), \
                 patch("builtins.input", side_effect=[reply]), \
                 patch.object(subprocess, "run", side_effect=AssertionError("Cancellation ran a command")):
                status, output, _ = self.run_cli(["configure"])
            self.assertEqual(status, expected)
            self.assertIn("Configuration unchanged", output)


class StatusTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        root = Path(self.temp.name)
        self.patches = [patch.object(policy, "DATA", root / "data"),
                        patch.object(policy, "CURRENT", root / "current"),
                        patch.object(policy, "battery_reading", return_value=(40, True)),
                        patch.object(policy, "watchdog_state_file", return_value=root / "state")]
        for replacement in self.patches:
            replacement.start()
        policy.atomic_write(policy.DATA / "user-level", "3")
        policy.atomic_write(policy.CURRENT, "3")

    def tearDown(self):
        for replacement in reversed(self.patches):
            replacement.stop()
        self.temp.cleanup()

    def test_sources_and_pending_target_are_distinct_from_applied_level(self):
        rules = policy.parse_rules("50:L5,25:L9")
        current, target, source, _ = policy.policy_status(rules, None)
        self.assertEqual((current, target), (3, 5))
        self.assertEqual(source, "battery ladder at 50% (L5)")
        self.assertEqual(policy.policy_status(rules, 9)[1:3], (9, "manual override until reboot"))
        self.assertEqual(policy.policy_status(policy.parse_rules(policy.DEFAULT_RULES), None)[1:3],
                         (3, "saved manual choice"))

    def test_status_uses_ladder_hysteresis(self):
        policy.atomic_write(policy.watchdog_state_file(),
                            '{"rules":"50:L5,25:L9","discharging":true,"lowest_percent":25}')
        self.assertEqual(policy.policy_status(policy.parse_rules("50:L5,25:L9"), None)[1:3],
                         (9, "battery ladder at 25% (L9)"))

    def test_unknown_applied_level_is_not_reported_as_zero(self):
        policy.CURRENT.unlink()
        self.assertIsNone(policy.policy_status(policy.parse_rules(policy.DEFAULT_RULES), None)[0])


if __name__ == "__main__":
    unittest.main()
