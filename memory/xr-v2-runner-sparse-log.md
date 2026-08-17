---
type: project
title: v2 strace runner truncates monado-service.log — orphan fd makes it sparse + unreadable
created: 2026-05-07
---

`.scratch/wayvr-trace/run-strace-v2.sh` opens
`/run/user/1000/monado-service.log` with `>` (truncate). If a previous
`monado-service` is still alive holding the old fd at a higher offset,
the kernel makes the file sparse — unused regions fill with NUL bytes
and ripgrep complains `binary file matches`.

## Symptoms

- `rg pattern /run/user/1000/monado-service.log` prints
  `binary file matches /run/user/1000/monado-service.log`
- `head` shows interleaved content from two runs in undecodable order
- `xxd` reveals long runs of `\x00` between log lines

## Root cause

```bash
"$MONADO" > "$MONADO_LOG" 2>&1 &
```

`>` truncates to length 0, but the orphan process still has its file
position at, say, byte 800000. Its next write seeks back to 800000 and
the kernel zero-fills bytes 0..800000. New monado writes from 0 forward;
the two streams interleave by offset, not by time.

## How to apply

Before starting any v2-runner cycle:

```bash
pgrep -af monado-service     # MUST be empty
```

If non-empty:

```bash
kill -INT $(pgrep -f monado-service)
# wait for graceful exit, then verify pgrep is empty before re-running
```

(Don't SIGKILL — see `xr-monado-sigkill-usb-stuck.md` and
`xr-shutdown-discipline.md`.)

## Possible permanent fix

Change the runner from `> "$MONADO_LOG"` to `rm -f "$MONADO_LOG"` or
use a per-run timestamped log file. Out of scope right now —
`.scratch/wayvr-trace/` is gitignored, edits live in Jorge's working
copy.
