---
name: bug
kind: program
services: [linus, prime, plan-debate, test-cycle, dev-bootstrap, auth-check, ship-pr, git-sync]
---

requires:
- request: the bug report or symptom description

ensures:
- report: a verified fix delivered as a pull request — with root-cause analysis, logs proving the bug is gone, a Linus-approved patch, and a full audit trail of every phase, decision, and artifact
- if the bug cannot be reproduced: a "could not reproduce" report with captured artifacts so the user can refine the reproduction steps
- if two follow-up patches still regress: detailed failure report and a Linus-written post-mortem on why the fix approach did not converge

invariants:
- no fix ships without instrumentation that lets us see it run
- no diagnosis is accepted without specific log lines or trace spans backing it
- "flaky" is never an accepted root cause
- Linus has the final word on every patch
- all development work happens in a git worktree — never on the main branch directly

strategies:
- when the first test-cycle signals unable-to-reproduce: surface to Linus immediately — he decides whether to widen the reproduction scope, ask the user for more reproduction steps, or close the bug as unconfirmed
- when bryan's post-fix validation shows a regression or the bug is not fully fixed: kick the patch back to prime with the validation report, then re-run test-cycle on the follow-up patch, bounded to 2 follow-up rounds

### Execution

# Sync — Pull remote updates if behind
let synced = call git-sync

# Bootstrap A — Dev environment + Auth check (independent, run in parallel)
parallel:
  let dev-ready = call dev-bootstrap
  let auth-instructions = call auth-check
    env: "local"

# Bootstrap B — Enter worktree
Enter a git worktree using EnterWorktree.

# Phase 0: Linus scopes the investigation and sets the debate depth
let scope = call linus
  task: "scope this bug: what's in/out, risks, prior context. Set plan-debate depth (skip|shallow|full|extensive)."
  request: request

# Phase 1: Test-cycle reproduces and diagnoses the bug
let diagnosis = call test-cycle
  task: "reproduce the reported bug and find the root cause"
  context: scope
  auth: auth-instructions

# Phase 2: Plan debate (depth set by Linus in Phase 0)
let plan = call plan-debate
  topic: request
  context: diagnosis
  depth: scope.depth

# Phase 3: Prime patches, Linus reviews, loop until accepted
loop until linus accepts the patch (max: 3):
  let patch = call prime
    task: "implement the fix per the agreed plan, minimal diff, no scope creep"
    diagnosis: diagnosis
    plan: plan
    review: review

  let review = call linus
    task: "review the patch for taste, simplicity, regressions, and adherence to the plan"
    patch: patch
    diagnosis: diagnosis

# Phase 4: Test-cycle verifies the fix
let verification = call test-cycle
  task: "verify the fix — original bug gone, no regressions"
  context: patch
  auth: auth-instructions

# Phase 5: Linus ships the PR — the PR IS the report
let pr-url = call ship-pr
  context: { scope, diagnosis, plan, patch, verification }

# Phase 6: Exit worktree
Exit the worktree using ExitWorktree.

return pr-url
