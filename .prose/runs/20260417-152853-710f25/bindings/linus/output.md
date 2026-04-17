# Linus Scope Document — Mosh Restore Bug

depth: shallow

---

## Scope Document

### In Scope

- Fix `restore-mosh.sh` so it correctly parses `session/window/pane` from tmux and matches the resurrect save file
- Ensure the fix handles the inline strategy invocation path (called via `tmux send-keys` in the restored pane's context)
- Update `FIXES.md` with the root cause and investigation

### Out of Scope

- Changes to tmux.conf resurrect process list (the `~mosh-client->...` mapping is correct)
- Changes to the bundled `plugins/tmux-resurrect/strategies/mosh-client_default_strategy.sh` (not used by our inline strategy path)
- Any other resurrect process patterns (nvim, ssh, etc. are working)
- Multi-user support (jorge/lewis does not use mosh)

### Risks

- Low. The fix is entirely self-contained in an 18-line shell script. No NixOS rebuild needed — it's a symlinked dotfile.
- The script must not use a shebang that produces different `\t` behavior across shells. Stay with `#!/usr/bin/env bash` and use `$'...'` ANSI-C quoting or `printf` for the format string.
- The script silently exits 1 when no host is found (the last line). That's acceptable behavior — resurrect will just skip the pane. Do not change the exit behavior.

---

## Root Cause (Confirmed by Tracing)

Running `bash -x restore-mosh.sh` reveals the bug immediately:

```
+ pane_id='eksno\t5\t1'
+ session='eksno\t5\t1'
+ rest='eksno\t5\t1'
```

The `tmux display-message -p '#{session_name}\t#{window_index}\t#{pane_index}'` call uses single quotes. In bash, single quotes prevent escape sequence interpretation, so `\t` is passed to tmux as a literal two-character sequence `\` + `t`. Tmux substitutes the format variables and outputs `eksno\t5\t1` — a string with literal backslash-t, not real tab characters.

Since the string contains no actual tabs, bash's `${pane_id%%<TAB>*}` parameter expansion finds nothing to strip and `session` / `window` / `pane` all equal the full original string. The awk then tries to match `$2 == "eksno\t5\t1"` against actual tab-separated fields and finds nothing. `$host` is empty. Script exits 1.

The fix is to use `$'...'` ANSI-C quoting so that `\t` is a real tab in the format string:

```bash
pane_id="$(tmux display-message -p $'#{session_name}\t#{window_index}\t#{pane_index}')"
```

This produces `eksno<TAB>5<TAB>1` and the parameter expansion splits correctly.

---

## Prior Context: All Previous Attempts

### Attempt 1 — `431eb4d` (2026-04-02): First introduction of restore-mosh.sh

**What was tried:** The script was written from scratch as part of a larger commit that also added word-boundary regex fixes to resurrect patterns. The approach was to use an inline strategy (`~mosh-client->~/.config/tmux/scripts/restore-mosh.sh`) so that when resurrect restores a mosh-client pane, it runs this script instead of the raw mosh-client command.

The script's design: at restore time, the script is already running inside the correct pane (resurrect does `select-pane` then `send-keys`). It calls `tmux display-message` to get the current pane's coordinates, then looks them up in the resurrect save file to find the original `-# hostname` argument, then calls `mosh $host`.

**What broke:** The single-quoted format string passes literal `\t` to tmux instead of tab characters. Variable splitting silently produces wrong results — all three variables (`session`, `window`, `pane`) equal the full unsplit string. awk matches nothing. `host` is empty. Script exits 1. No error is displayed to the user because the exit happens silently.

**Why it wasn't caught:** The commit message says the feature was "added" — it was written but apparently not tested end-to-end against an actual resurrect restore cycle. The script itself executes without crashing (bash's `[[` and parameter expansion on a string with no tabs just return empty results silently).

### Attempt 2 — `b772ef7` (2026-04-13): File rename, no logic change

**What happened:** The `refactor(dotfiles)` commit moved `dotfiles/tmux/scripts/restore-mosh.sh` to `dotfiles/default/tmux/scripts/restore-mosh.sh`. The script contents were unchanged (git shows `similarity index 100%`). The bug persisted unchanged.

---

## Git History Summary

| Commit | Date | Change | Learning |
|--------|------|--------|----------|
| `431eb4d` | 2026-04-02 | Created `restore-mosh.sh`; added `~mosh-client->restore-mosh.sh` inline strategy to tmux.conf; added `sleep 5` pre-restore hook | Script has `\t` quoting bug from day one; not caught because no end-to-end test |
| `0d2c15e` | 2026-04-02 | Word-boundary regex fix (same day, likely a fixup) | Not related to mosh |
| `b772ef7` | 2026-04-13 | Renamed file to `default/` path | No logic change; bug carried forward |

No FIXES.md entry exists for mosh restore. This is the first debugging pass.

The bundled resurrect strategy at `dotfiles/default/tmux/plugins/tmux-resurrect/strategies/mosh-client_default_strategy.sh` uses a different (and simpler) approach: it receives `$ORIGINAL_COMMAND` as `$1` and strips the `-#` prefix to produce `mosh <hostname> <args>`. We do NOT use this strategy — our inline strategy mapping bypasses it entirely and calls `restore-mosh.sh` directly. The two approaches are independent.

---

## Plan-Debate Depth Decision

**depth: shallow**

The root cause is definitively confirmed with a `bash -x` trace. There is exactly one line to fix (`pane_id=...`) and one correct fix (`$'...'` quoting). There are no design questions, no ambiguous tradeoffs, no unknowns.

A full or extensive debate would be wasted cycles on a one-line mechanical fix. Shallow is appropriate: confirm the fix is correct, write it, test it, ship it.

The only thing worth a brief discussion is whether to keep the `tmux display-message` lookup approach at all versus passing the pane coordinates as arguments from the resurrect context. But that would require changes to tmux.conf (the inline strategy syntax) and is a bigger refactor. The current approach is fine once the quoting bug is fixed.
