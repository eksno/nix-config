---
name: git-sync
kind: program
---

requires: (none — operates on the current branch)

ensures:
- synced: the current branch is up to date with the remote

invariants:
- never force-pulls or resets — only fast-forward merges
- if the pull fails due to conflicts, surface the error to the caller instead of resolving silently

### Execution

Fetch from the remote.
Check if the current branch is behind its upstream.
If it is behind, pull to bring it up to date.

return synced
