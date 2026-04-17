# Fix Plan: restore-mosh.sh tab delimiter bug

## The Change

Line 8 of `dotfiles/default/tmux/scripts/restore-mosh.sh`:

```diff
-pane_id="$(tmux display-message -p '#{session_name}\t#{window_index}\t#{pane_index}')"
+pane_id="$(tmux display-message -p $'#{session_name}\t#{window_index}\t#{pane_index}')"
```

Single quotes to `$'...'` ANSI-C quoting. That's it. One character added.

## Why This Is Sufficient

- The `\t` sequences are the only broken part. Single quotes pass literal backslash-t to tmux, which tmux doesn't interpret as tabs either (tmux format strings don't process `\t`). The result is fields glued together with no delimiter.
- Lines 9-12 use literal embedded tab characters for field splitting (verified in the file). Once `tmux display-message` actually emits tabs, the `${pane_id%%\t*}` / `${rest#*\t}` parameter expansions work correctly.
- The awk on lines 14-15 uses `-F'\t'` which is fine -- awk does interpret `\t` in `-F` regardless of shell quoting because awk handles it internally.
- Field mapping (`$2=session, $3=window, $6=pane_index, $11=command`) was confirmed correct against the tmux-resurrect save file format.

## Risks / Edge Cases

1. **Session names with tabs**: Technically a tmux session name could contain a tab. This would break field splitting. In practice nobody does this and tmux-resurrect's own save format also uses tab delimiters with no escaping, so this is a non-issue -- if your session name has a tab, resurrect itself is already broken.
2. **Shell compatibility**: `$'...'` is POSIX-ish but not strictly POSIX. The script uses `#!/usr/bin/env bash` so this is fine -- bash has supported ANSI-C quoting since forever.
3. **No other callers**: The script is only invoked by tmux-resurrect's inline strategy mapping. No other code depends on its output format.

Zero risk. Mechanical fix.

## FIXES.md Entry

Should cover:

- **Symptom**: mosh sessions not restored after tmux-resurrect restore (script exits silently, pane gets default shell instead of reconnecting)
- **Affected**: `dotfiles/default/tmux/scripts/restore-mosh.sh:8`, all hosts/users with tmux-resurrect
- **Root cause**: Single-quoted `\t` in `tmux display-message -p` format string. Bash single quotes prevent escape interpretation, and tmux itself doesn't interpret `\t` in format strings either. Result: session/window/pane fields concatenated with no delimiter, so all downstream field splitting produces empty values, awk match fails, `$host` is empty, script skips the `exec mosh` line.
- **Investigation**: bash -x trace showed pane_id contained no tabs. Confirmed save file format uses tabs and awk field mapping is correct. Identified single-quote as the sole issue.
- **Fix**: Changed single quotes to `$'...'` ANSI-C quoting so `\t` becomes actual tab characters.
- **Commit**: to be filled after committing
