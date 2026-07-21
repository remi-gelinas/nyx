# Agentic harness modules

Claude Code agent harness configuration: roles under `orchestration/claude/`, skills under `*/_skills/`, and the supporting hooks and proxy plumbing.

## Authoring agent roles and skills

When adding or modifying an agent role, a skill, or any instruction that dispatches agents, answer this at authoring time: **what is the input corpus, and is it bounded?**

- Bounded inputs (a scoped diff, owned files, a queryable JSONL) can be read directly.
- Unbounded corpora (session transcripts, whole-wave diffs, repository-wide audits) must never be read raw — they run from 100k to millions of tokens and exhaust the agent's context. The role must prescribe an extraction-first method: derive a file or item list first (`git diff --name-only`, `jq`/`grep` skeletons), read only the intersecting hunks or records, process one item at a time, and accumulate condensed findings in a scratch file rather than in context.

Roles that violated this (harness-miner reading transcripts, docs-warden reading wave diffs) consistently died at their context limit; their current charters show the corrected pattern.

When changing a policy, grep for its echoes before finishing: rules repeat across `general.md`, the skills, and the role charters, and an agent obeys the nearest copy — a stale prohibition in a role charter silently overrides the updated global policy for every agent spawned from it (this bit the git-writes policy and the TeamCreate references).

MCP servers registered through `programs.claude-code.mcpServers` surface at runtime with plugin-namespaced tool names (`mcp__plugin_claude-code-home-manager_<server>__<tool>`), not `mcp__<server>__<tool>`. Role allowlists must grant the runtime name — verify it from a live session's tool list before granting, because a wrong name fails silently as a permission denial the agent never reports (this bit codebase-memory: every teammate was blocked from the graph while all the guidance said to use it).
