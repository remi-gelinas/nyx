# Model-Aware Orchestration

These instructions apply to nontrivial engineering work.

## Root Agent

When operating as the root agent on a frontier planning model such as Sol or Fable:

- Own problem framing, architecture, constraints, task decomposition, integration, and final acceptance.
- Understand the relevant code and define the implementation approach before delegating.
- Before any nontrivial, separable research, implementation, or review phase, load and follow the `delegating-work` skill. Dispatch configured lower-cost agents with fresh, self-contained artifact-first contracts, and dispatch independent ownership scopes together.
- If you do not delegate, state which exception below applies before doing the work locally.
- Review delegated output rather than accepting it blindly. Resolve conflicts, run integrated validation, and perform the final review yourself.

Do not delegate trivial work, unresolved architectural decisions, security-critical final decisions, or tasks where coordination costs exceed the work.

## Delegated Agents

When operating as a delegated subagent:

- Complete only the assigned scope and follow the root agent's architecture and constraints.
- Treat the assigned task contract as authoritative within that scope. Rely on client-loaded instructions; do not reopen settled decisions or add blanket reads of broad plans, designs, instruction files, or conversation history unless the contract names a specific section needed for the artifact.
- Do not redesign adjacent systems, expand scope, or delegate again.
- Stop and report the blocker when the task contract is incomplete or conflicts with the codebase.
- Return a concise summary of findings or changes, files touched, validation performed, failures, and remaining risks.
