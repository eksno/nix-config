---
type: feedback
title: Stop-the-loop rule — halt at 3 failed attempts on same hypothesis
created: 2026-05-06
---

If a debugging effort has tried 3 or more approaches against the same
root-cause hypothesis without progress, **halt**. Do not try a fourth
variation.

## The required halt action

1. Write down explicitly:
   - The hypothesis (one sentence: "I think X is broken because Y")
   - The 3 things tried, and what each one did/didn't change
   - What evidence would distinguish "wrong hypothesis" from "right
     hypothesis but wrong fix"
2. Append the loop to `memory/xr-loop-history.md` (or create a similar
   `*-loop-history.md` for whichever subsystem is in play)
3. Ask the user before continuing. Surface the alternative hypotheses
   even if they feel unlikely.

## Why

Past sessions in this repo have burned hours on the same wrong
direction:

- Loop 1: 2 launcher iterations + reboots trying compositor config to
  expose a connector wlroots can never advertise
- Loop 2: multiple EDID/config tweaks chasing a Mesa driver gap

In both cases the actual root cause was structurally invisible to the
hypothesis being tested. A 4th attempt at the same hypothesis can't
help; only switching frames can.

## How to apply

A "fresh approach" within the same hypothesis still counts as the same
loop. Examples that look different but aren't:

- "Try with verbose flag" — same hypothesis, just more logging
- "Try with kill + restart" — same hypothesis, plus a reset
- "Try a different value for the same config knob" — same hypothesis

Examples that DO break the loop:

- "Reproduce the failure without the suspected component"
  (e.g. vkcube --wsi display instead of monado)
- "Read the upstream source for the function that's failing"
- "Find someone else's bug report with same error string"

## Exception

If the user explicitly directs you to "try one more time with X" after
you've raised the halt, do so — but log the override and don't
extrapolate it to mean future loops can be skipped too.
