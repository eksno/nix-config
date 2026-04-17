# Test-Cycle Diagnosis: Mosh Restore Bug

## Reproduction

**Status: REPRODUCED** (confirmed via code analysis and save file inspection)

### Evidence

1. **Current script** (`dotfiles/default/tmux/scripts/restore-mosh.sh:8`):
   ```bash
   pane_id="$(tmux display-message -p '#{session_name}\t#{window_index}\t#{pane_index}')"
   ```
   Single quotes prevent bash from interpreting `\t` as tab. tmux receives literal `\t` (backslash + t) and passes it through unchanged.

2. **Actual save file** (`~/.local/share/tmux/resurrect/last`) contains a mosh entry:
   ```
   pane	eksno	1	0	:	1	mosh pluto ~	:/home/eksno	1	mosh-client	:/nix/store/.../mosh-client -# pluto | 144.76.155.176 60003
   ```
   The file uses real tab separators between fields.

3. **Field mapping verified**:
   - $1=pane, $2=session, $3=window, $6=pane_index
   - pane_index=1 (because `setw -g pane-base-index 1` in tmux.conf:15)
   - $11 contains the full mosh-client command with `-# pluto`

4. **What happens with single-quote `\t`**:
   - tmux outputs: `eksno\t1\t1` (literal backslash-t, not tab)
   - bash parameter expansion `${pane_id%%<TAB>*}` finds no tabs to split on
   - session/window/pane all equal the full unsplit string
   - awk matches nothing, host is empty, exit 1

5. **The fix** — `$'...'` ANSI-C quoting:
   - bash interprets `\t` as real tab before passing to tmux
   - tmux outputs: `eksno<TAB>1<TAB>1` (real tabs)
   - parameter expansion splits correctly
   - awk finds the matching pane entry
   - host = "pluto", exec mosh pluto

## Root Cause

**Single-quoted `\t` in tmux display-message format string.** The `\t` is never interpreted as a tab character by either bash or tmux, causing all downstream field splitting to silently fail.

## Additional Notes

- No other issues found in the script logic
- The awk pattern uses `match()` with capture group (requires gawk, which is default on NixOS)
- The resurrect inline strategy mapping in tmux.conf:70 is correct: `~mosh-client->~/.config/tmux/scripts/restore-mosh.sh`
- No FIXES.md entry exists for mosh restore — this needs one
