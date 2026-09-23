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
    if not text:
        raise ValueError("the threshold list is empty. Enter a list such as 25:notif,10:notif.")
    if len(text) > 1200:
        raise ValueError("the threshold list exceeds 1200 characters. Use a shorter list.")
    rules = []
    seen = set()
    previous = 101
    for entry in text.split(","):
        if not entry:
            raise ValueError("an entry is empty. Remove extra commas and the trailing comma.")
        if any(character.isspace() for character in entry):
            raise ValueError(f"entry {entry!r} contains whitespace. Remove spaces and line breaks.")
        if entry.count(":") != 1:
            raise ValueError(f"entry {entry!r} has an invalid format. Use PERCENT:ACTION.")
        percentage, action = entry.split(":")
        if not re.fullmatch(r"([1-9][0-9]?|100)", percentage):
            raise ValueError(f"percentage {percentage!r} is invalid. Use an integer from 1 to 100 without leading zeros.")
        threshold = int(percentage)
        if threshold in seen:
            raise ValueError(f"threshold {threshold} appears twice. Use each percentage once.")
        if threshold >= previous:
            raise ValueError(f"threshold {threshold} follows {previous}. Put percentages in descending order.")
        if not re.fullmatch(r"notif|L[0-9]", action):
            raise ValueError(f"action {action!r} is invalid. Use notif or L0–L9.")
        rules.append((threshold, action))
        seen.add(threshold)
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


def battery_reading():
    battery = next((b for b in sorted(POWER_SUPPLY.glob("BAT*"))
                    if (b / "energy_now").exists()), None)
    if battery is None:
        return None
    return (int((battery / "capacity").read_text()),
            (battery / "status").read_text().strip() == "Discharging")


def watchdog_state_file():
    # sudo can remove XDG_RUNTIME_DIR; use the calling user's runtime directory.
    uid = os.environ.get("SUDO_UID", str(os.getuid()))
    directory = os.environ.get("XDG_RUNTIME_DIR", f"/run/user/{uid}")
    return Path(directory) / "power-mode-watchdog.json"


def policy_status(rules, override):
    manual = read_level(DATA / "user-level", 0)
    reading = battery_reading()
    source = "saved manual choice" if (DATA / "user-level").exists() else "default level"
    target = manual
    if reading is not None:
        percent, discharging = reading
        path = watchdog_state_file()
        previous = json.loads(path.read_text()) if path.exists() else {}
        target, _, state = plan(rules, percent, discharging, manual, override, previous)
        if discharging:
            for threshold, action in rules:
                if state["lowest_percent"] <= threshold and action.startswith("L"):
                    source = f"battery ladder at {threshold}% ({action})"
    if override is not None:
        target = override
        if any(action.startswith("L") for _, action in rules):
            source = "manual override until reboot"
        else:
            source = "saved manual choice (persists across reboots)"
    return read_level(CURRENT), target, source, reading


def show_policy_status():
    text, rules = read_rules()
    current, target, source, reading = policy_status(rules, read_level(RUNTIME / "manual-override"))
    print("Power policy")
    print(f"  Applied level: {f'L{current}' if current is not None else 'unknown'}")
    if reading is None and any(a.startswith("L") for _, a in rules):
        print("  Target: unavailable (no battery detected)")
    else:
        pending = " (pending application)" if current != target else ""
        print(f"  Target: L{target}{pending}")
        print(f"  Target source: {source}")
    print(f"  Thresholds: {text}")
    print("  Configure: power-mode configure --help")


def configure(text):
    if text is None:
        raise ValueError("No thresholds supplied. Run 'power-mode configure' for the guided prompt.")
    rules = parse_rules(text)  # Validate the complete input before changing any file.
    atomic_write(DATA / "rules", text + "\n")
    # Explicit configuration starts the new ladder now.
    (RUNTIME / "manual-override").unlink(missing_ok=True)
    print(f"Saved thresholds: {text}")
    for threshold, action in rules:
        description = "notify only" if action == "notif" else f"select {action} and notify"
        print(f"  At {threshold}%: {description}.")
    if any(action.startswith("L") for _, action in rules):
        print("Automatic level changes are enabled.")
        print("New manual selections override the ladder until reboot.")
    else:
        print("Automatic level changes are disabled. Manual selections persist across reboots.")
    print("The manual override is cleared. The watchdog applies this configuration on its next poll.")
    try:
        current, target, _, reading = policy_status(rules, None)
        if reading is None:
            print("No battery detected. The current target cannot be determined.")
        elif current != target:
            current_text = f"L{current}" if current is not None else "an unknown level"
            print(f"At the current battery state, the level will change from {current_text} to L{target}.")
        else:
            print(f"At the current battery state, the level remains L{target}.")
    except (ValueError, OSError) as error:
        print(f"Configuration saved, but the level preview is unavailable: {error}", file=sys.stderr)
    print("Run 'power-mode status' to check the applied level.")


def remember_manual(level):
    _, rules = read_rules()
    if not any(action.startswith("L") for _, action in rules):
        atomic_write(DATA / "user-level", f"{level}\n")
    atomic_write(RUNTIME / "manual-override", f"{level}\n")


def tick(power_mode, notify_send):
    reading = battery_reading()
    if reading is None:
        return
    _, rules = read_rules()
    percent, discharging = reading
    state_file = watchdog_state_file()
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
    commands.add_parser("status")
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
        elif args.command == "status":
            show_policy_status()
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
