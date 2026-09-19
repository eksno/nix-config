"""Public CLI routing. Help and validation run before privileged operations."""

import re
import subprocess
import sys

import policy

CONTINUE = 64
OVERVIEW = """power-mode — manage power levels and battery notifications

Usage: power-mode <level|command> [arguments]

Commands:
  0–9                   Select a manual level (L0: performance, L9: power saving)
  status                Show battery, hardware settings, and the active level's source
  configure [rules]     Configure thresholds; omit rules for a guided text prompt
  config                Print the current threshold list
  charge-limit [20–100]  Show or set the maximum battery charge
  calibrate             Measure power use for each level
  stretch <hours>       Select a level from calibration data

Examples:
  power-mode 5
  power-mode configure '75:notif,50:L5,25:L9,10:notif'

Run 'power-mode --help' for general help.
Run 'power-mode configure --help' for battery ladder examples and rules.
"""
CONFIGURE_HELP = """Configure battery notifications and automatic power levels.

Usage: power-mode configure [rules]

Examples:
  power-mode configure
      Open a guided text prompt with the current configuration.
  power-mode configure '25:notif,10:notif'
      Restore the default: notify at 25% and 10%, without automatic level changes.
  power-mode configure '75:notif,50:L5,25:L9,10:notif'
      Notify at 75%, select L5 at 50%, select L9 at 25%, and notify at 10%.
      Every level action also gives a notification.
  power-mode config
      Show the current threshold list.

Syntax:
  Each entry is PERCENT:ACTION. Separate entries with commas.
  Percentages range from 1 to 100 and must descend without duplicates.
  Actions are notif or L0–L9. Do not include spaces or a trailing comma.
  notif only gives a notification. It does not change the level.

Behavior:
  A list with any level action enables an automatic level ladder.
  A manual selection overrides the ladder until reboot, including charger changes.
  Notifications continue during an override. After reboot, the ladder resumes.
  Without a ladder, manual selections persist across reboots.
  Above the first level threshold, the saved manual level applies.
  Connecting power restores the saved manual level unless an override is active.
  Each threshold notifies once per discharge cycle.
  After suspend, passed thresholds produce one combined notification.

Saving clears the manual override. The watchdog applies the configuration on its next poll.
A level can change immediately if a level threshold has already been reached.
Invalid input leaves the current configuration unchanged.
At the prompt, press Enter to keep the current configuration or Ctrl-C to cancel.
"""
GENERAL_HELP = OVERVIEW + """
Power levels:
  L0 gives full performance. Higher levels increase power saving.
  L9 gives maximum power saving. Hardware limits depend on the machine.
  Example: power-mode 5

Battery automation:
  The default is 25:notif,10:notif: notifications only.
  Automatic level changes require an explicit level ladder.
  Manual levels persist across reboots when no ladder is configured.
  With a ladder, a manual level overrides it until reboot.

Help:
  power-mode <command> --help
  power-mode help <command>
  -h and --help show help without sudo or hardware changes.
"""
HELP = {
    "configure": CONFIGURE_HELP,
    "config": """Print the current threshold list.

Usage: power-mode config
Example: power-mode config

This command does not change settings. Its output can be used in scripts.
Run 'power-mode configure --help' to learn how to change the thresholds.
""",
    "status": """Show battery measurements, hardware settings, and power policy.

Usage: power-mode status
Example: power-mode status

The policy shows the applied level and the expected level, including pending changes.
The source is a saved manual choice, a ladder threshold, or an override until reboot.
""",
    "level": """Select a manual power level.

Usage: power-mode <0–9>
Example: power-mode 5

L0 gives full performance. L9 gives maximum power saving.
Without a ladder, this choice persists across reboots.
With a ladder, this choice overrides all automatic level changes until reboot.
""",
    "charge-limit": """Show or set the maximum battery charge.

Usage: power-mode charge-limit [20–100]
Examples:
  power-mode charge-limit       Show the current limit.
  power-mode charge-limit 80    Limit charging to 80%.

Battery hardware must support a charge limit.
""",
    "calibrate": """Measure power use at each level for the stretch command.

Usage: power-mode calibrate
Example: power-mode calibrate

Disconnect the charger first. Calibration puts the CPU under load for about three minutes.
Run 'power-mode stretch --help' to use the saved measurements.
""",
    "stretch": """Select a power level for a requested battery duration.

Usage: power-mode stretch <hours>
Example: power-mode stretch 4.5

Hours must be a positive number. Run 'power-mode calibrate' first.
The selected level follows the same persistence rules as a manual level.
Battery duration is an estimate and depends on the workload.
""",
}


def error(message):
    print(f"power-mode: {message}", file=sys.stderr)
    return 2


def help_for(topic):
    if re.fullmatch(r"[0-9]", topic):
        topic = "level"
    if topic not in HELP:
        return error(f"Cannot show help: unknown command {topic!r}. Run 'power-mode --help'.")
    print(HELP[topic], end="")
    return 0


def prompt(executable):
    if not sys.stdin.isatty():
        return error("Cannot open the prompt: input is not a terminal. Supply rules as an argument.")
    current, _ = policy.read_rules()
    print(f"Current thresholds: {current}")
    print("notif only notifies. L0–L9 selects a level and also notifies.")
    print("Use percentages 1–100 in descending order, without duplicates or spaces.")
    print("Example: 75:notif,50:L5,25:L9,10:notif")
    print("Default: 25:notif,10:notif (notifications only)")
    print("With a ladder, manual selections override it until reboot.")
    print("Saving clears the current override and can change the level on the next poll.")
    print("Press Enter to keep the current configuration, or Ctrl-C to cancel.")
    while True:
        try:
            text = input("Thresholds> ")
            if not text:
                print("Configuration unchanged.")
                return 0
            policy.parse_rules(text)
        except ValueError as exc:
            error(f"Cannot save configuration: {exc}\nYour configuration is unchanged.")
            continue
        except (EOFError, KeyboardInterrupt):
            print("\nConfiguration unchanged.")
            return 130
        return subprocess.run([executable, "configure", text], check=False).returncode


def dispatch(args, executable):
    if not args:
        print(OVERVIEW, end="")
        return 0
    if args[0] == "help":
        if len(args) == 1:
            print(GENERAL_HELP, end="")
            return 0
        if len(args) != 2:
            return error("Cannot show help: too many arguments. Use 'power-mode help <command>'.")
        return help_for(args[1])
    if "-h" in args or "--help" in args:
        if args[0] in ("-h", "--help"):
            print(GENERAL_HELP, end="")
            return 0
        return help_for(args[0])
    command, *values = args
    if command == "configure":
        if not values:
            return prompt(executable)
        if len(values) != 1:
            return error("Cannot save configuration: expected one threshold list. Run 'power-mode configure --help'.")
        try:
            policy.parse_rules(values[0])
        except ValueError as exc:
            return error(f"Cannot save configuration: {exc}\nYour configuration is unchanged.")
    elif command == "config" and not values:
        print(policy.read_rules()[0])
        return 0
    elif command in ("status", "calibrate") and not values:
        pass
    elif re.fullmatch(r"[0-9]", command) and not values:
        pass
    elif command == "--auto" and len(values) == 1 and re.fullmatch(r"[0-9]", values[0]):
        pass
    elif command == "charge-limit" and (not values or (
            len(values) == 1 and re.fullmatch(r"[0-9]{2,3}", values[0]) and 20 <= int(values[0]) <= 100)):
        pass
    elif command == "stretch" and len(values) == 1 and re.fullmatch(r"[0-9]{1,6}(\.[0-9]{1,6})?", values[0]) and float(values[0]) > 0:
        pass
    else:
        topic = command if command in HELP else ""
        hint = f"power-mode {topic} --help" if topic else "power-mode --help"
        return error(f"Cannot run command: invalid command or arguments {args!r}. Run '{hint}'.")
    return CONTINUE


if __name__ == "__main__":
    try:
        sys.exit(dispatch(sys.argv[2:], sys.argv[1]))
    except (OSError, ValueError) as exc:
        sys.exit(error(str(exc)))
