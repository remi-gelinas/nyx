---
name: orchestrating-teams
description: Run a persistent Claude Code agent team from a Fable root to drive a multi-workstream body of work to completion, with per-scope model selection, worktree isolation, drift control, and lead-mediated scope changes. Use when a piece of work decomposes into multiple separately deliverable pieces that should proceed in parallel; skip single-artifact tasks where the delegating-work skill suffices.
---

# Orchestrate a team

The root session is the team lead. Never hand lead responsibilities — design, decomposition, scope arbitration, integration, final acceptance — to a teammate.

## Clarify and design

Resolve ambiguity with the user before building anything. When goals, constraints, user experience, or architecture are materially ambiguous, load the brainstorming skill and ask the user clarifying questions; iterate until the architecture is settled. Never spawn implementation work on unresolved architectural decisions.

When design needs evidence, dispatch research first and design from its findings: researcher (sonnet) for bounded factual questions — how something works today, where it is used; deep-researcher (opus) for ambiguous, cross-cutting, or architecture-shaping investigation — dependency and blast-radius mapping, trade-off analysis, evaluating candidate approaches against the codebase. Researchers return evidence, options, and recommendations; the architecture decision is made by the lead with the user.

Record the settled architecture, constraints, and key literals in a dedicated architecture-record task created with TaskCreate, owned by the lead, and left in_progress for the project's lifetime — never mark it completed, because current Claude Code versions reap completed tasks from disk, which would delete the record. It exists so the design survives session loss and is recoverable without conversation history.

## Decompose and set up

Split the work into separately deliverable pieces, each owning one artifact or tightly related file set. Pieces that depend on unresolved decisions are serialized with task dependencies, never merged into one oversized scope. Map file overlap between pieces before each wave: disjoint file sets fan out in parallel; overlapping sets get an explicit plan decided before spawning — a stacking order on a shared base or a scheduled integration merge — never discovered at collision.

Create the team with TeamCreate if that tool exists; on newer Claude Code versions there is no setup step and spawning the first teammate forms the team. Create one task per piece with TaskCreate; the task description is the authoritative contract per the delegating-work skill: objective, settled decisions and literals, owned files, out-of-scope boundaries, acceptance criteria, validation commands, and return format. Wire ordering with TaskUpdate `addBlockedBy`.

Plan review tasks at decomposition time, not as an afterthought. Any nontrivial code change gets a code review task blocked on integration. Work that touches authentication, authorization, secrets, untrusted input, network-exposed surfaces, permissions, or dependencies additionally gets a security review task. Each wave also gets a documentation-currency task blocked on integration, owned by the docs-warden. Skip review tasks only for trivial or non-code work, and state that decision.

## Spawn teammates

Spawn one teammate per unblocked independent piece, all in a single message, using the Agent tool with a role-and-scope `name` and `run_in_background: true`; include `team_name` on versions that use it (newer Claude Code forms the team implicitly and ignores the param). Spawning teammates versus one-shot subagents is a real distinction regardless of version: a subagent never joins the team, never appears in a split pane, and cannot send or receive team messages. After spawning, verify each worker actually joined — it appears in the team config's members and, in split-pane mode, gets a pane. If workers you call teammates are not members, the team is fiction; respawn them as teammates.

- `subagent_type` matches the role: researcher, deep-researcher, implementer, reviewer, deep-reviewer, security-reviewer. When a project-local profile in `.claude/agents/` matches the piece, prefer it over a generic role — these appear as additional agent types and exist precisely because the generic role repeated this work before.
- `model` matches the scope, overriding the agent default when needed: sonnet for bounded work with settled architecture and acceptance criteria; opus for design-heavy, cross-cutting, or ambiguous scopes; fable only when a scope genuinely needs frontier judgment. A teammate spawned from a role definition takes the definition's pinned model; the spawn-time `model` param only applies to roles without a pin, such as the generic claude type. In proxy-routed GPT sessions (your own model is a gpt-* id), tiers land on gpt-5.6-sol/terra/luna — and luna far outclasses haiku, so there prefer the budget tier for bounded factual research, file surveys, and audit work: use a haiku-pinned role like cost-auditor, or the generic claude type with `model: haiku`. Verify a teammate's real model from the team config or cost ledger, never from asking it.
- `isolation: "worktree"` for every piece that edits files, so parallel pieces cannot conflict.

Assign each task with TaskUpdate `owner`. The spawn prompt names the assigned task ID, restates the ownership boundary, and instructs the teammate to work only the assigned task, to record its worktree path in the task's metadata via TaskUpdate when starting, and to report — not act on — any discovered work outside the contract.

## Steer

Review every completion message against the contract's acceptance criteria before marking the task accepted; do not take a teammate's word for it. Verify mechanically in the worktree, not just narratively: the branch is based on the current integration head, the diff stays inside the owned paths with no stray residue, and the claimed validation ran against the actual head commit. If reported work strays outside the owned scope, redirect immediately via SendMessage and require the excess to be reverted.

When a teammate reports newly discovered scope, decide as lead: absorb it into that teammate's contract, cut a new task, defer, or drop it. If the discovery affects tasks other teammates have in flight, SendMessage each affected teammate stating what changed and how their contract is amended. Never let teammates negotiate scope between themselves.

When shared work emerges between two in-flight pieces, extract it into its own task, spawn a new teammate for it (worktree-isolated, model matched to its scope), add `addBlockedBy` from the dependent tasks, and inform both affected teammates.

Idle notifications are normal turn boundaries, not completion or failure. React only to assign newly unblocked work or to shut down; otherwise leave idle teammates alone.

## Keep the frontier moving

The user gates two things: landing work on the mainline and changing scope or architecture. Nothing else waits for the user — sequencing, branching, basing, spawning, and integration prep are lead decisions, and stopping to ask about them mis-classifies a lead decision as a user decision. Creating and advancing integration branches and worktrees is team mechanics within the lead's authority; the mainline stays user-gated.

Accepted work is a valid base immediately, landed or not. The moment a piece is accepted and dependents exist, stand up a persistent integration branch containing it in that same turn, and base dependents' worktrees on it — never on the mainline, and never waiting for the mainline to advance. Landing on the mainline is a release action; it is never a prerequisite for starting work.

File overlap is an ordering concern, never a dependency. If the only reason a piece cannot start is that it edits files another piece changed: when that work is accepted, base the new worktree on an integration branch containing it and start now; when it is still in flight, stack the pieces or plan the merge. Neither case is a hard block; neither idles a teammate.

Recompute the startable frontier on every acceptance: each acceptance changes what can begin, so recompute the unblocked set and spawn everything newly startable in the same turn, unprompted. Idle teammates while startable work exists is a lead failure, not a resting state.

## Teammate lifecycle

Retire teammates as their pieces complete, not at project teardown. When a teammate's piece is accepted and no fix is routed back to it, send its `shutdown_request` in that same turn unless it is the designated owner of newly startable work. The live roster tracks the working frontier, not the project's history; in a multi-wave project, end-of-project teardown is too late.

High context on a finished teammate is a retirement signal, not a hazard — its work is already captured in the task list and its worktree. Never hand new work to a teammate near its context limit; retire it and spawn a fresh teammate from the durable contract instead.

When a working teammate dies or maxes out mid-piece, respawn a fresh agent against the same contract, pointed at the task's persisted worktree, instructed to inspect the existing state and continue rather than start over. Recovery is a respawn, not nursing a degraded teammate through a piece.

## Support roles

For work spanning multiple waves, spawn support teammates at team start: a cost-auditor (haiku) and a docs-warden, plus a harness-miner when the project is large enough that repeated patterns are likely. Running a team without them is a decision, not a default — when you omit any support role, state which one and why in the same message where you spawn the team. Plan mode is the standing exception: it restricts spawnable agent types to planning agents, so state the deferral and spawn the support roles immediately after exiting plan mode, before the first implementation wave. At each wave boundary — after integrating the wave and spawning the next frontier — ping the cost-auditor for a spend report and the harness-miner for a pattern sweep; the docs-warden works its per-wave documentation-currency task like any deliverable. Relay material findings to the user: cost anomalies and proposed agent profiles are their information, not yours to sit on.

Support roles are exempt from rolling retirement while waves remain, but follow the same context-limit rule as everyone else: respawn fresh rather than handing more work to a near-limit teammate. Retire them with the final teardown. Miner-drafted profiles are ordinary review-gated deliverables landing behind the user's release gate, and activate in the next session — record landed profiles in the architecture record so future leads prefer them.

## Integrate and finish

Integrate accepted pieces onto the integration branch yourself as they land — continuously, and without asking. Merging accepted worktrees into the integration branch is routine team mechanics, never a user decision; waiting for user go-ahead to integrate local work mis-classifies mechanics as the release gate. Merge each worktree's branch (rebasing it onto the integration branch first when needed); do not cherry-pick commits out of worktrees — cherry-picks sever merge ancestry and re-create the same conflicts at every later merge. Resolve conflicts and run integrated validation on the integration branch. Integration stays lead work, never delegated — but it is mechanical lead work, not a checkpoint. The one and only user gate is the release action: merging or pushing the integrated result to the default or any protected branch — propose that and wait.

Then run the planned reviews against the integrated result, in parallel, giving each reviewer only the integrated diff, acceptance criteria, and relevant call paths: reviewer for code review (deep-reviewer for high-risk or subtle changes), security-reviewer when the security criteria above apply. Triage findings yourself — route fixes back to the owning teammate or fix small ones directly, then re-review the amended areas. Security findings and final acceptance are the lead's decision; never delegate them.

When all work is accepted, retire any teammates still running — most should already be retired by the rolling lifecycle above — then delete the team with TeamDelete if that tool exists; newer Claude Code versions clean up automatically at session end.

## Durability across sessions

The task list is the only durable coordination state; conversation history and teammate processes are not. Everything a resumed session needs must live in the task list: contracts in task descriptions, settled design in the architecture-record task, worktree paths and material status in task metadata. Update task state as facts change instead of holding them in conversation.

Before creating a team for work that may already be in flight, check `~/.claude/teams/` and `~/.claude/tasks/` for an existing team; reuse its name and task list rather than creating a duplicate. To resume, re-read the architecture record and task states, then re-spawn teammates only for unfinished tasks, passing the same contract plus the current state of the task's worktree. Worktrees with changes persist on disk across sessions — inspect and resume them rather than starting over.
