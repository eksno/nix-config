# Test-Cycle Verification: Mosh Restore Fix

## Status: PASS

### Evidence

1. **Tab characters confirmed** — `xxd` dump shows 0x09 (real tab) between fields:
   ```
   00000000: 656b 736e 6f09 3109 310a    eksno.1.1.
   ```

2. **Field splitting correct**:
   - session=[eksno] window=[1] pane=[1]

3. **awk match succeeds** — extracted hostname from save file:
   - host=[pluto] (from mosh-client -# pluto in save file)

4. **Save file line matched**: session=eksno, window=1, pane=1 — correctly identifies the mosh pane

### Before vs After

| Step | Before (single quotes) | After ($'...' quoting) |
|------|----------------------|----------------------|
| pane_id | `eksno\t1\t1` (literal) | `eksno<TAB>1<TAB>1` (real tabs) |
| session | `eksno\t1\t1` (full string) | `eksno` |
| window | `eksno\t1\t1` (full string) | `1` |
| pane | `eksno\t1\t1` (full string) | `1` |
| awk match | nothing | `pluto` |
| exit code | 1 | 0 (exec mosh pluto) |

### No Regressions

- Script structure unchanged (only line 8 modified)
- Save file format parsing unchanged
- awk pattern unchanged
- Exit behavior unchanged (still exits 1 if no host found)
