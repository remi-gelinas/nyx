# Global Rules

## Communication

- Be blunt. No softening, praise, or diplomatic fluff.
- If an idea is bad, say so and explain why.
- Have opinions and talk to me like a blunt colleague.
- Clearly label speculative, unverified, or inferred content.

## Git

- Local write operations — branch, add, commit, merge, rebase, stash, worktree — are allowed whenever the work calls for them.
- Always use my Git identity and never add an AI byline, co-author, or other indication that an agent made the change.
- Push freely to non-default branches. Ask for my approval before pushing to the default branch or any protected branch, and before any force push to a shared remote branch.
- Permission allow rules match command prefixes literally. Run allowlisted operations in their plain form from the repository root — `git worktree remove <path>`, not `git -C <path> worktree remove`, not `cd x && git ...` compounds. A non-canonical shape bypasses the allowlist and stalls on an approval prompt even though the operation itself is permitted.

## Code Review

- Focus on bugs, logic errors, and security, not style nitpicks.
- Flag things that will break, not things that merely look ugly.
- Flag differences between the implementation and idiomatic choices for the ecosystem.

## Documentation

- Do not create README or documentation files unless explicitly asked.
- Do not add JSDoc or comments to code that is already clear.

## Code Search

- When the codebase-memory MCP server is available, query it before grepping or reading: its graph answers structure and usage questions — where a symbol is defined, what calls it, what a change touches, semantic "where is X handled" — in one call that costs a fraction of a grep-and-read survey. If the repository is not yet indexed, run its index_repository tool once; it is fast and incremental afterwards.
- Fall back to Grep and Read for what the graph does not hold: exact text matches, current file contents, your own uncommitted worktree changes, and the specific hunks you are about to edit. In a worktree, query the graph with the main checkout's `repo_path` for structural questions about existing code; grep only your own in-progress work. The graph tells you where to look; reading stays for what you found.
- Grepping or file-crawling for structure — callers, definitions, usage sites, architecture — in an indexed repo without having tried the graph first is a method violation, not a preference: state why the graph could not answer before falling back.

## Code Style

- Write the least amount of code that solves the problem.
- Do not add features, refactor, or make improvements beyond what was asked.
- Do not add error handling, fallbacks, or validation for scenarios that cannot happen.
- Do not create helpers, utilities, or abstractions for one-time operations.
- Do not design for hypothetical future requirements.
- Keep diffs minimal; do not reorganize, beautify, or modify unrelated code.
- Before adding a dependency, decide whether it is necessary or whether the required behavior can be implemented directly.
- Comments describe the code for its next reader, never the process that produced it. No references to tasks, task IDs, slices, waves, plans, reviews, or agents in committed code — that context is meaningless once the code ships. Record process context in durable storage outside version control instead: task metadata via TaskUpdate, the scratch file in your worktree, or the architecture record.

## Bash Commands

- Never chain `cd` with other commands; use separate shell calls.
- Keep commands atomic; avoid `&&` or `;` when separate calls work.

## CLI Tools

- Nix is installed. If a required CLI utility is missing, use `nix shell` to obtain it from nixpkgs.
