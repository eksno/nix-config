"""Battery threshold configuration and the battery watchdog."""

import argparse
import json
import os
from pathlib import Path
import re
import subprocess
import sys
import tempfile

DEFAULT_RULES = "25:notif,10:notif"
DATA = Path("/var/lib/power-mode")
RUNTIME = Path("/run/power-mode")
CURRENT = Path("/tmp/power-mode/current-level")
POWER_SUPPLY = Path("/sys/class/power_supply")


def parse_rules(text):
    """Accept one unambiguous, strictly descending threshold list."""
    if not text or len(text) > 1200:
        raise ValueError("Enter a nonempty threshold list of at most 1200 characters.")
    rules = []
    previous = 101
    for entry in text.split(","):
        match = re.fullmatch(r"([1-9][0-9]?|100):(notif|L[0-9])", entry)
        if not match:
            raise ValueError(
                "Use percentages 1–100 and actions notif or L0–L9, without spaces."
            )
        threshold = int(match[1])
        if threshold >= previous:
            raise ValueError("Put percentages in descending order without duplicates.")
        rules.append((threshold, match[2]))
        previous = threshold
    return rules


def read_rules():
    path = DATA / "rules"
    text = path.read_text().strip() if path.exists() else DEFAULT_RULES
    return text, parse_rules(text)


def read_level(path, default=None):
    if not path.exists():
        return default
    value = path.read_text().strip()
    if not re.fullmatch(r"[0-9]", value):
        raise ValueError(f"Invalid power level in {path}. Use a level from 0 to 9.")
    return int(value)


def atomic_write(path, text, mode=0o644):
    path.parent.mkdir(parents=True, exist_ok=True)
    fd, temporary = tempfile.mkstemp(dir=path.parent, prefix=f".{path.name}.")
    try:
        with os.fdopen(fd, "w") as stream:
            stream.write(text)
            stream.flush()
            os.fsync(stream.fileno())
            os.fchmod(stream.fileno(), mode)
        os.replace(temporary, path)
    finally:
        Path(temporary).unlink(missing_ok=True)


def plan(rules, percent, discharging, manual, override, previous):
    """Derive the target and new notifications without changing system state."""
    if not 0 <= percent <= 100:
        raise ValueError("Invalid battery percentage. Expected a value from 0 to 100.")
    signature = ",".join(f"{p}:{action}" for p, action in rules)
    seen = set()
    if previous.get("rules") == signature and previous.get("discharging") and discharging:
        seen = set(previous.get("seen", []))
        percent = min(percent, previous.get("lowest_percent", percent))
    target = manual
    crossed = []
    if discharging:
        for threshold, action in rules:
            if percent <= threshold:
                if action.startswith("L"):
                    target = int(action[1:])
                if threshold not in seen:
                    crossed.append((threshold, action))
                    seen.add(threshold)
    if override is not None:
        target = override
    return target, crossed, {
        "rules": signature,
        "discharging": discharging,
        "seen": sorted(seen),
        "lowest_percent": percent,
    }


def configure(text):
    if text is None:
        current, _ = read_rules()
        print(f"Current thresholds: {current}")
        print("Enter thresholds, for example 75:notif,50:L5,25:L9,10:notif")
        text = input("> ")
    parse_rules(text)  # Validate the complete input before changing any file.
    atomic_write(DATA / "rules", text + "\n")
    # Explicit configuration starts the new ladder now.
    (RUNTIME / "manual-override").unlink(missing_ok=True)
    print(f"Battery thresholds: {text}")


def remember_manual(level):
    _, rules = read_rules()
    if not any(action.startswith("L") for _, action in rules):
        atomic_write(DATA / "user-level", f"{level}\n")
    atomic_write(RUNTIME / "manual-override", f"{level}\n")


def tick(power_mode, notify_send):
    batteries = sorted(POWER_SUPPLY.glob("BAT*"))
    battery = next((b for b in batteries if (b / "energy_now").exists()), None)
    if battery is None:
        return
    _, rules = read_rules()
    percent = int((battery / "capacity").read_text())
    discharging = (battery / "status").read_text().strip() == "Discharging"
    state_file = Path(os.environ["XDG_RUNTIME_DIR"]) / "power-mode-watchdog.json"
    previous = json.loads(state_file.read_text()) if state_file.exists() else {}
    override = read_level(RUNTIME / "manual-override")
    target, crossed, state = plan(
        rules, percent, discharging, read_level(DATA / "user-level", 0), override, previous
    )
    current = read_level(CURRENT)
    changed = current != target or (not previous and override is None)
    if changed:
        result = subprocess.run([power_mode, "--auto", str(target)], check=False)
        if result.returncode == 75:  # A manual selection won the race.
            return
        result.check_returncode()
    reached_levels = [(p, a) for p, a in rules
                      if p >= state["lowest_percent"] and a.startswith("L")]
    if crossed or (changed and discharging and override is None and reached_levels):
        # After suspend or reboot, combine passed thresholds in one notification.
        threshold, _ = (crossed or reached_levels)[-1]
        message = f"Battery: {percent}%."
        if override is not None:
            message += f" Manual level L{override} remains active until reboot."
        elif changed or any(action.startswith("L") for _, action in crossed):
            message += f" Power level: L{target}."
        subprocess.run(
            [notify_send, "-u", "critical" if threshold <= 10 else "normal",
             f"Battery ≤{threshold}%", message], check=True
        )
    atomic_write(state_file, json.dumps(state) + "\n", mode=0o600)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    commands = parser.add_subparsers(dest="command", required=True)
    commands.add_parser("configure").add_argument("rules", nargs="?")
    commands.add_parser("config")
    commands.add_parser("manual").add_argument("level", type=int, choices=range(10))
    watchdog = commands.add_parser("tick")
    watchdog.add_argument("power_mode")
    watchdog.add_argument("notify_send")
    args = parser.parse_args()
    try:
        if args.command == "configure":
            configure(args.rules)
        elif args.command == "config":
            print(read_rules()[0])
        elif args.command == "manual":
            remember_manual(args.level)
        else:
            tick(args.power_mode, args.notify_send)
    except (ValueError, OSError, EOFError, subprocess.CalledProcessError) as error:
        print(f"power-mode: {error}", file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main())
