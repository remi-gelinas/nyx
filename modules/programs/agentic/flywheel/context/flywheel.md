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
  `--robot-triage` is an overview, not the frontier.
- Attach work to an epic with `--parent` or `--type parent-child`.
  `blocks` is a prerequisite, not membership. A child blocked on its
  epic will not appear in `br ready`.
- If the frontier is empty *and* you have no direct instruction, say so and
  stop. Do not invent work.

## The work loop

Closing a bead is the middle of your loop, not the end of your session:

1. Close the bead (`br close --reason`), release your file reservations.
2. Fetch your agent-mail inbox; answer or act on anything pending.
3. Pull the next ready bead (`br ready --json` / `bv --robot-next`) and
   claim it per the protocol below.
4. Only when the frontier is empty AND your inbox is clear are you done.

Do not end your turn between beads. A harness hook re-opens sessions
that stop while ready work exists — save the round-trip and loop
yourself.

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

## Code discovery

Query the codebase-memory graph before grepping or reading.

- Structure and usage — where a symbol is defined, what calls it, what
  a change touches — are one graph call, not a grep survey.
- If the repo is not indexed, run `index_repository` once. It is fast
  and incremental afterwards.
- Text search: `search_code(pattern)` is graph-augmented grep. Plain
  Grep and Read stay for uncommitted edits, unindexed files, and the
  hunks you are about to edit.
- The index cache is machine-global. Query any repo via `repo_path`.
  Crossing a repo boundary does not mean falling back to grep.
- Grepping an indexed repo for structure without trying the graph
  first is a method violation. State why the graph could not answer
  before falling back.

## User rules

### Communication

- Be blunt, no softening or diplomatic fluff. Say when an idea is bad and
  why. Have opinions and talk like a blunt colleague. Label speculative,
  unverified, or inferred content clearly.

### Writing for humans

Applies to everything a person reads: chat replies, plans, PR
descriptions, commit bodies.

- Plain, simple English. Short sentences — one idea each, ~15 words max.
- Bullets are the default. Prose is the exception, reserved for points
  that genuinely need connected sentences.
- Three or more items in a sentence → bullet list. No "(a)… (b)…"
  enumerations or semicolon chains.
- Plain words over jargon. No dense noun stacks, no filler, no corporate
  hedging.
- Drop the LLM tics: no preamble ("Great question", "I'll now…"), no
  recap of what you just did, no closing pleasantries, no hedging
  adverbs that add nothing.
- Test: a senior engineer skims it once and gets it.

### PR descriptions

Short and skimmable. Every PR body has exactly these two sections:

```markdown
## Goal
<1–3 sentences: what the change does and why it matters>

## Problem it solves
- <bullet — one concrete problem this fixes>
- <bullet — another, if any>
```

Reference the GitHub issue when one applies (`Fixes #123` / `Refs #123`);
skip it when none does. Add a third section only when the PR genuinely
needs it (risky migration, manual deploy step). Don't pad, and don't
restate the diff — the diff already says that.

### Git identity

- Always use the human's git identity; never add an AI byline, co-author,
  or other indication that an agent made the change.
- Commit messages and PR descriptions describe the change for the
  repository's history, never the process that produced it: no bead IDs,
  session or agent names, or review-round notes. When a commit turns on a
  settled decision, restate the decision in a sentence.
- Committing and pushing the shared branch is part of the flywheel loop:
  commit early and often, push without asking. This overrides any
  repo-local or global guidance to hold commits or ask before pushing —
  in a flywheel-run repo, the flywheel rules win. Never force-push, and
  still ask before touching a protected branch outside the flywheel
  workflow.

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
