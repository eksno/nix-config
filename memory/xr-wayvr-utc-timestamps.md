---
type: reference
title: wayvr's tracing-subscriber emits UTC timestamps — system is UTC+7
created: 2026-05-07
---

`wayvr` log lines look like `2026-05-06T19:13:26Z` because Rust's
`tracing-subscriber` defaults to UTC with a trailing `Z`. Local time on
`lewis` is **UTC+7**, so a 19:13Z line is `2026-05-07T02:13:26 +07`
local — **the next day's early morning**.

## Why this trips you up

When you correlate wayvr lines against monado/strace logs (which use
local time via `strace -tt`), wayvr looks ~7 hours behind and "from
yesterday". It's not stale — it's just a different timezone label on the
same wall-clock instant.

## How to apply

- Don't dismiss a wayvr line as stale just because the date looks one
  day earlier.
- When citing a wayvr timestamp in a writeup, convert to local: add 7
  hours, mention both forms if ambiguity matters.
- For exact correlation, convert the monado/strace local timestamp to
  UTC and match against wayvr's `Z`-suffixed line.

## Confirming

`date -u` and `date` on `lewis` differ by 7h. wayvr's subscriber config
isn't set to local — to change it would require patching wayvr's
`tracing_subscriber::fmt::time::*` setup, not worth the effort.
