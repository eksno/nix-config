# Power mode

Set a manual level with `power-mode 5`. Levels range from L0 to L9.
L0 gives full performance. L9 gives maximum power saving.

The default thresholds are `25:notif,10:notif`. They give notifications without automatic level changes.
Without a level ladder, your manual level survives reboot.

## Configure battery thresholds

Run `power-mode configure` to enter a threshold list at the text prompt.
You can also supply the list directly:

```sh
power-mode configure '75:notif,50:L5,25:L9,10:notif'
```

Use `power-mode config` to show the current list.
To restore the default, run:

```sh
power-mode configure '25:notif,10:notif'
```

Percentages must range from 1 to 100 and appear in descending order.
Each percentage can appear only once. Do not include spaces or a trailing comma.
Each action must be `notif` or a level from `L0` to `L9`.
Invalid input leaves the existing configuration unchanged.

- `notif` gives a notification without changing the power level.
- `L5` selects level 5 and gives a notification. Other levels work the same way.
- A list with any level action is an automatic level ladder.

The ladder uses the last level action reached as the battery discharges.
Above the first level threshold, the saved manual level applies.
A `notif` threshold leaves that level unchanged.
Small percentage increases during discharge do not reverse the ladder.

A manual selection overrides the entire ladder until reboot, including across charger changes.
Notifications continue during this override. After reboot, the ladder resumes at the current battery percentage.
The override does not replace the saved manual level from before the ladder was enabled.
Without an override, connecting power restores that saved manual level.

Configuration applies immediately and clears the current manual override.
Notifications occur once per threshold during each discharge cycle.
After suspend or reboot, passed thresholds produce one combined notification at the lowest reached threshold.

## Verification

Run the policy tests from this directory:

```sh
python3 -m unittest -v test_policy.py
```
