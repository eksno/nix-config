---
name: ship-pr
kind: program
services: [linus]
---

requires:
- context: all prior phase outputs — scope, diagnosis/plan, patch, verification, artifacts

ensures:
- pr-url: a pull request URL with Linus authoring the title and body

errors:
- no-code-changed: no files were modified in the worktree — Linus writes a summary report to the user instead of opening a PR

invariants:
- the PR is the single source of review — anyone reading it should understand what happened, why, and what to check
- Linus's voice, framing, and judgment — not boilerplate

### Execution

let pr-url = call linus
  task: "commit all changes and create a pull request. The body is the audit trail — anyone reading it should fully understand what happened. Include links to all artifacts. Keep the title under 70 chars."
  context: context

return pr-url
