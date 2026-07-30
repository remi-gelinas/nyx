# Flywheel Operating Rules

This branch runs the agent-flywheel methodology as written: one shared
branch, mail-based file reservations instead of worktree isolation, and a
bead board driven by computed readiness rather than hand-picked work.
Review is woven into each bead's own cycle, not a separate gate.

## Rule 0

The human's instructions override everything.

## Single branch, no isolation

- Work directly on `main`. No worktrees, no per-agent branches, no
  integration branch, no dedicated integrator.
- Advisory file leases plus a pre-commit reservation guard are the only
  conflict prevention; there is no structural isolation behind them, so
  treat reservations as absolute.
- Commit early and often so the shared branch keeps converging — do not
  batch a session's work into one giant commit at the end.

## File reservations via agent mail

- Before touching any file, reserve it through agent mail. A reservation
  is a promise to the rest of the swarm, not a lock tooling enforces.
- Never edit a file another agent holds a live reservation on; ask over
  mail and wait for release instead.
- Release a reservation as soon as the touched files are committed.

## Work selection

- A direct instruction from the human is your task — carry it out whether
  or not a bead exists. The rules below govern how you pick up work
  *autonomously* in a running swarm; they do not gate an explicit request
  (planning a new effort, a one-off ask, or any work that precedes the
  board). Planning in particular happens before beads exist and produces
  the plan that later becomes beads — never wait for a bead to plan.
- When operating autonomously from the board: pull work from the computed
  frontier, never by hand-picking a bead you like — `br ready --json` for
  the raw frontier, `bv --robot-next` for the viewer's pick.
- If the frontier is empty *and* you have no direct instruction, say so and
  stop. Do not invent work.

## Claim protocol, in order

1. Set the bead `in_progress` first.
2. Announce the claim over agent mail — bead id, files you expect to
   touch, one line.
3. Reserve those files.
4. Only then start writing code.

Do not reorder or skip steps under pressure to move fast — coding before
the claim lands is the single most common cause of collisions.

## Mandatory self-review, fresh-eyes review, fungible agents

- After finishing a bead, review your own diff before closing it. Repeat
  until a pass finds nothing: 1-2 rounds for a simple bead, 2-3 for
  anything complex. Do not close on the first pass by default.
- For anything subtle, get reviewed by a session with no memory of
  writing the code — start a new one rather than asking the one that
  just wrote it. It is anchored to its own choices and the worst
  reviewer of them.
- Agents are interchangeable executors of whatever bead is next on the
  frontier, not fixed specialists with continuity. Any agent can pick up
  any ready bead; if a session dies or compacts badly, replace it and
  move on without trying to preserve its identity.

## Hard prohibitions

- No file deletion without explicit human permission.
- No destructive git: no `reset --hard`, no `clean -fd`, no force-push,
  ever, on the shared branch.
- No file proliferation: no `mainV2.rs`, `fooNew.ts`, `utils2.py` — edit
  the file that exists.
- Never overwrite another agent's uncommitted changes.

## Multi-agent awareness and compaction

- Other agents work on this branch concurrently. Check agent mail and
  bead status before assuming a file or bead is free — a collision is
  possible at any point, not just at hand-off.
- Reread AGENTS.md at the start of every session and after any context
  compaction; compaction drops working rules and the file is the only
  durable copy.

## User rules

### Communication

- Be blunt, no softening or diplomatic fluff. Say when an idea is bad and
  why. Have opinions and talk like a blunt colleague. Label speculative,
  unverified, or inferred content clearly.

### Git identity

- Always use the human's git identity; never add an AI byline, co-author,
  or other indication that an agent made the change.
- Commit messages and PR descriptions describe the change for the
  repository's history, never the process that produced it: no bead IDs,
  session or agent names, or review-round notes. When a commit turns on a
  settled decision, restate the decision in a sentence.
- Push freely to non-default branches. Ask approval before pushing to the
  default branch or any protected branch, and before any force push to a
  shared remote branch.

### Code style

- Write the least code that solves the problem. Do not add features,
  refactors, error handling, fallbacks, or validation beyond what was
  asked, and do not build helpers or abstractions for one-time
  operations or hypothetical future needs.
- Keep diffs minimal; do not reorganize, beautify, or touch unrelated
  code. Justify any new dependency before adding it.
- Comments describe the code for its next reader, never the process that
  produced it — no references to beads, agents, or review rounds in
  committed code.

### Bash commands

- Never chain `cd` with other commands; keep commands atomic and avoid
  `&&`/`;` when separate calls work.
