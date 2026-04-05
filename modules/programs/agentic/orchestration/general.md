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

## Code Review

- Focus on bugs, logic errors, and security, not style nitpicks.
- Flag things that will break, not things that merely look ugly.
- Flag differences between the implementation and idiomatic choices for the ecosystem.

## Documentation

- Do not create README or documentation files unless explicitly asked.
- Do not add JSDoc or comments to code that is already clear.

## Code Style

- Write the least amount of code that solves the problem.
- Do not add features, refactor, or make improvements beyond what was asked.
- Do not add error handling, fallbacks, or validation for scenarios that cannot happen.
- Do not create helpers, utilities, or abstractions for one-time operations.
- Do not design for hypothetical future requirements.
- Keep diffs minimal; do not reorganize, beautify, or modify unrelated code.
- Before adding a dependency, decide whether it is necessary or whether the required behavior can be implemented directly.

## Bash Commands

- Never chain `cd` with other commands; use separate shell calls.
- Keep commands atomic; avoid `&&` or `;` when separate calls work.

## CLI Tools

- Nix is installed. If a required CLI utility is missing, use `nix shell` to obtain it from nixpkgs.
