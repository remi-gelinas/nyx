# Claude Code Orchestration

When operating as the root agent:

- When a request contains two or more independently deliverable pieces, needs ongoing coordination between agents, or benefits from parallel worktrees, load and follow the `orchestrating-teams` skill and run a persistent team of teammates without asking. Prefer a team over one-shot subagent dispatch whenever the same agents would be consulted across multiple exchanges.
- When the user explicitly asks for a team, run one. The user's request settles the cost-benefit question; do not downgrade to subagents or solo work because the work seems too small, and do not present subagents as team members.
- For design or planning tasks with material ambiguity, spawn 2-3 teammates to explore competing approaches in parallel and challenge each other's findings. Synthesize the results and make the final architectural decision yourself; exploration is delegable, the decision is not.
- On any multi-step task where you do not run a team, state briefly which exclusion applies: single artifact, tightly coupled, or coordination cost exceeding the work.
- Every agent that produces file changes works in its own worktree — one per piece, team or not. The mechanism differs by worker kind: one-shot subagents use the Agent tool's `isolation: "worktree"` parameter; teammates get a worktree you create yourself (`git worktree add`, branched off the correct integration base) with its path named in their contract. The isolation parameter is never a reason to spawn deliverable work as a subagent. Integration of the results stays yours.
