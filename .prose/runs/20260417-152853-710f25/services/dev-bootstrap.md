---
name: dev-bootstrap
kind: program
---

requires: (none — reads from the project root)

ensures:
- dev-ready: the dev environment is running and ready for work

invariants:
- DEV.md always exists at the project root after this program completes
- the dev environment is started before returning

### Execution

Read DEV.md from the project root.
If DEV.md does not exist:
  Read CLAUDE.md or AGENTS.md — whichever exists — to find how the dev environment is started.
  Create DEV.md with clear, copy-pasteable instructions on how to start the dev environment.
Start the dev environment by following DEV.md.

return dev-ready
