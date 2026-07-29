# Flywheel Operator Playbook

The human's crib for the agent-flywheel methodology
([agent-flywheel.com/complete-guide](https://agent-flywheel.com/complete-guide)).
The tools mechanize the inner loop; everything on this page is the outer loop
you drive by hand. Agents have their own instructions (AGENTS.md and the
global context) — this file is for you.

## The cost law that orders everything

Work moves Plan Space → Bead Space → Code Space. A defect costs roughly
**1x to fix in the plan, 5x in the beads, 25x in the code**. Every ritual
below exists to catch problems in the cheapest space that can catch them.
When tempted to skip a step, name which space the skipped defects will
surface in instead.

## Phase 1 — Plan Space

**Intent brief.** Explain the goal to one frontier session in plain English:
what it does, who uses it, constraints, what done looks like. Ask for an
initial markdown plan covering architecture, workflows, edge cases, and
testing obligations. Plans are long by design (the guide's run thousands of
lines); resist summarizing.

**Competing plans.** Give the same intent brief to independent sessions on
different model families — here: a `claude` session and a `codex` session,
in separate panes, neither seeing the other's output. Independence is the
point; do not let one critique before both have drafted.

**Synthesis.** Feed both plans to a fresh session:
> You have two independent plans for the same system. Produce a single
> best-of-all-worlds hybrid: take each section from whichever plan handles
> it better, flag every point where they disagree, and resolve each
> disagreement with your reasoning stated.

**Blunder hunts (repeat ~5x).** On the synthesized plan, fresh session each
round:
> Read this plan looking ONLY for blunders: contradictions between sections,
> missing workflows, edge cases with no owner, unstated assumptions,
> anything that cannot work as written. Do not praise; do not summarize;
> list defects with the section they live in.
Stop when a round comes back empty. Also run one **inversion pass**: "argue
this plan is wrong — what would its critics say, and which criticisms are
right?"

**For features on an existing codebase**, run the Idea-Wizard funnel before
any plan: ask a session for ~30 candidate ideas → have it winnow to the best
5 with reasoning → expand those into ~15 concrete variations → you pick.
Check `br list --json` first so you don't fund a duplicate.

The plan goes static once beads exist. You will not look back at it — every
decision that must survive goes into the beads.

## Phase 2 — Bead Space

**Conversion.** One session converts the plan into beads: self-contained
(an agent must never need the plan), acceptance criteria and test
obligations on every bead, dependencies wired with `br dep add`. Batch
via markdown/JSON import if the plan is large.

**Polish 4–6 rounds — "check your beads N times, implement once."** This is
the guide's most-repeated advice and its author's named under-investment.
Rotate the lens each round, fresh eyes each time:
1. Granularity — split anything an agent couldn't finish in one sitting.
2. Dependency sanity — `br dep cycles --json` must be empty; `bv
   --robot-insights` for bottlenecks.
3. Duplicate merge and description sharpening.
4. Acceptance criteria — mechanical, checkable, test obligations named.
5. Contradiction hunt — beads that disagree with each other.
6. `bv --robot-suggest` for hygiene the graph can see.

**The plan-bead gap is a named failure mode**: synthesis finishes and nobody
converts. The transition is a scheduled work step, not an afterthought.

## Phase 3 — Swarm

**Launch.** From the repo (after `flywheel-init` has run once):
```
ntm spawn <project> --cc=2 --cod=2      # start small; scale after a clean wave
```
In each pane before work starts, identity must exist:
```
export BR_ACTOR=<name> AGENT_NAME=<name>   # distinct per pane
```
Unset, br attribution collapses to "assistant" and the lease guard fails
commits outright. Agent names are disposable; the guide likes whimsical ones.

**Rate limits**: no account rotation exists here (CAAM was excluded). A
stalled swarm mid-wave is the documented failure mode — run ~4 agents until
you've seen how the seat holds, and stagger launches.

## Phase 4 — The clockwork-deity loop

Check in every 10–30 minutes; the guide's whole human role is this loop:

- `bv --robot-triage` — the mega-command: counts, top picks, blockers.
- `br list --status in_progress --json` — who claims what.
- `ntm activity` / `ntm dashboard` — pane states at a glance.
- Agent looks confused or just compacted? Send the guide's most-used
  intervention, verbatim: **"Reread AGENTS.md so it's still fresh in your
  mind."**
- **Reality check, once per session**: is the actual goal closer, or is the
  swarm just busy? Strategic drift looks like productivity — commits flowing
  while the destination recedes. Judge against the intent, not the diff.
- Surprises become beads immediately (`br create`), never side quests.
- Ad-hoc changes too small for a bead are allowed; if one turns out to
  matter, create the bead retroactively.

## Review layers (no merge gate exists — these replace it)

1. **Immediate self-review** after every bead, the prompt roughly:
   > Carefully read all the new code you just wrote, looking super carefully
   > for obvious bugs, edge cases, and places it doesn't match the bead.
   Repeat until a round finds nothing (1–2 rounds simple, 2–3 complex).
2. **Fresh-eyes review**: a brand-new session (never the author, never a
   warm session — anchoring is the enemy) reviews the diff against the bead.
3. **ubs before every commit**: `ubs <changed-files>` — exit 0 or fix and
   re-run.
4. Reviewer checklist: matches the bead spec; edge/concurrency/boundary
   cases; does the same bug pattern exist elsewhere; is there a simpler
   shape.

## Session end (every agent, every session)

```
git pull --rebase
br sync --flush-only
git add .beads/ && git commit
git status        # must be clean
```
Push policy stays this repository's own: pushes are asked for, not assumed.

## Failure modes, for recognition

Improvised architecture (weak plan) · the plan-bead gap · improvisational
swarm (vague beads) · oscillating quality (skipped polish) · "drug-addled
children" post-compaction (skipped reread) · reply-all spam and trampled
files (skipped mail/leases) · random work selection (ignoring bv) ·
anchored reviews (warm reviewers) · strategic drift (busy ≠ closer) ·
stalled swarm (rate limits, no rotation here).
