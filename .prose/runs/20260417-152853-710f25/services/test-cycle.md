---
name: test-cycle
kind: program
services: [theo, bryan]
---

requires:
- task: what to instrument, test, and analyze
- context: any prior context relevant to the test (a scope document, a diagnosis, a patch, or a feature plan)
- auth (optional): authentication instructions from AUTH.md — passed through to Theo

ensures:
- result: combined test-and-analysis report — Theo's artifacts (console logs with instrumentation events, network requests, screenshots, GIF recording, pass/fail) plus Bryan's analysis (anomalies found, hidden errors caught, root cause if applicable, verdict on whether the test genuinely passed at every layer)
- if bryan signals inconclusive-after-max-rounds: best-available analysis with flagged unknowns and a list of what still needs investigation

invariants:
- Theo always instruments and deploys before testing — never test against undeployed code
- Bryan always reviews after Theo — a test that passed visually might have failed on the backend
- the Theo-Bryan pair is the atomic unit of quality evidence in this team

### Execution

# Phase 1: Theo instruments, deploys, and tests
let test-run = call theo
  task: task
  context: context
  auth: auth

# Phase 2: Bryan analyzes — catches what Theo missed, including hidden backend errors
let analysis = call bryan
  task: "analyze Theo's test artifacts and produce a verdict on whether the test genuinely passed"
  test-run: test-run

# Phase 3: If Bryan needs more evidence, Theo re-instruments and retests
loop until bryan is satisfied with the evidence (max: 3):
  if bryan signals evidence-insufficient or found hidden issues that need targeted instrumentation:
    let test-run = call theo
      task: "address Bryan's findings and retest"
      context: context
      analysis: analysis
      auth: auth
    let analysis = call bryan
      task: "re-analyze with the new evidence"
      test-run: test-run

return analysis
