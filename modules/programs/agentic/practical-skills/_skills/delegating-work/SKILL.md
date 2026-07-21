---
name: delegating-work
description: Delegate nontrivial separable engineering research, implementation, and review from Sol/Fable roots through small authoritative artifact-first task contracts, running independent scopes in parallel while retaining architecture, integration, and acceptance. Use at the start of every nontrivial engineering task handled by Sol or Fable, including investigation, implementation, debugging, migration, and review; skip trivial, tightly coupled, security-critical, or architecturally unresolved work.
---

# Delegate work

Own problem framing, architecture, decomposition, integration, and final acceptance as the root.

Before dispatch, split the work so each agent owns one concrete output artifact or tightly related file set. A research report and review findings count as artifacts. Never bundle multiple subsystems into one task. Launch independent ownership scopes together; serialize shared files, mutable state, dependencies, and unresolved decisions.

Write a small self-contained task contract containing the objective, exact settled decisions and literals, owned scope, only the context needed for that artifact, constraints, acceptance criteria, validation method and commands when applicable, and return format. The contract is authoritative within the delegated scope. Rely on client-loaded instructions, and inline fixed decisions instead of sending the agent through broad designs, plans, instruction files, or conversation history.

Start agents with the smallest context the client supports. Continue interrupted work with the same agent. If replacement is unavoidable, pass only the authoritative contract, current artifact or diff, and remaining work.

Require the output artifact and validation evidence as the deliverable. Process advice such as “use apply_patch early” is not a deliverable. Tell agents not to reopen settled decisions or explore outside the owned scope unless the contract is incomplete or conflicts with higher-priority instructions.

Do not delegate trivial work, tightly coupled work, security-critical decisions, or work blocked on architecture. State the applicable exception before doing such work locally.

Require delegated agents to avoid further delegation, documentation, adjacent redesign, and scope expansion unless explicitly assigned. Git scope follows the shared rules: local commits inside an assigned worktree are fine when the flow needs them; pushing, branch or worktree creation, and touching trees outside the assignment stay forbidden.

Inspect all returned artifacts and diffs. Integrate them yourself and run integrated validation. Give the final reviewer only the integrated diff or artifact, acceptance criteria, and relevant call paths. Do not pass broad history or create per-task review loops.
