# Flywheel tool reference

Repo-agnostic reference for the flywheel toolchain. This is global
operator context (delivered to `~/.claude/CLAUDE.md` and
`~/.codex/AGENTS.md`), not committed into any project — it applies to
every session while the flywheel harness is active.

Your agent identity is the name ntm assigned you — the "You are agent
<name>" line injected at session start; ntm has already registered you
with agent-mail under it, and `AGENT_NAME` was exported into your
environment at launch, so git commits satisfy the lease guard without
any setup. Use exactly that name in every mail call, and if you call
`register_agent`, always pass `name=<your name>` (an idempotent profile
update) — a bare call mints a second identity whose reservations will
not match your commits. Never edit `.git/hooks/*` or wrap the guard's
hooks — the
chain-runner executes `pre-commit.orig`, so fronting or backing up
hooks creates recursion. The one place you must supply identity
yourself is br: pass `--actor <your agent name>` on every mutating br
call (`create`/`update`/`close`). Unset, br attributes everything to
the literal "assistant" and per-agent history collapses.

## br + bv (issue tracking)

`br` is the issue-tracking binary — **never `bd`**, that name is
legacy. `bv` is a read-only sidecar viewer over the same
`.beads/issues.jsonl`: bv tells you *what* to work on, br is how you
create, update, and close it. **Never run bare `bv`** — with no flags
it drops into an interactive TUI that blocks the session; always pass a
`--robot-*` flag.

`--robot-triage` is the single entry point for "what should I do now":
it returns `quick_ref`, `recommendations`, `quick_wins`,
`blockers_to_clear`, `project_health`, and `commands` in one payload.
Only `quick_ref.top_picks` and any item carrying a non-empty
`claim_command` are actually claimable right now — `recommendations`
can list work that is still blocked, so don't claim off that list
without checking.

5-step workflow: `br ready --json` (or `bv --robot-next`) to find work
→ `br update --actor "$ACTOR" <id> --status in_progress --claim` →
work → self-review → `br close --actor "$ACTOR" <id> --reason "..."`.
Priority runs 0 (highest) through 4; type is one of epic/task/bug/chore;
dependencies are directed edges (`blocks`, `parent-child`) that gate
readiness — `br dep add <child> <parent> --type blocks` and
`br dep tree|list|cycles <id> --json` inspect them.

Git policy: br never commits or pushes — git stays your job. In a
flywheel-run repo the flywheel operating rules govern git: commit early
and often, and push the shared branch without asking. That takes
precedence over any repo-local or global guidance to commit only when
asked. Commit messages never carry bead IDs — the bead id belongs in
`br close --reason`, mail thread_ids, and reservation reasons, not in
the repository's history.

## br command cheat-sheet

- **ALWAYS `--json`.** Never parse br's human-formatted output.
- **ALWAYS `--actor "$ACTOR"`** on every mutating call — `create`,
  `update`, `close` all require it. Set `ACTOR` once to your assigned
  agent name (the "You are agent <name>" line), not to `BR_ACTOR` —
  nothing exports that; the name in your instructions is the source.
- `br create --actor "$ACTOR" "Title" -p 1 -t task [--assignee X
  --labels a,b --description "..."]`
- `br update --actor "$ACTOR" <id> --status in_progress --claim`
- `br ready --json`
- `br dep add <child> <parent> [--type blocks]`
- `br dep tree|list|cycles <id> --json`
- `br close --actor "$ACTOR" <id> --reason "..."`
- `br sync --flush-only|--import-only|--status` — sync is explicit,
  never automatic; br has no daemon, no hooks, no auto-commit.
- `--format toon` on any command for token-optimized output when
  context is tight.
- Session end: `git pull --rebase`; `br sync --flush-only`; then commit
  and push code changes. NEVER commit `.beads/` — the board is
  machine-local swarm state, excluded via `.git/info/exclude`; the
  repo's other contributors don't use the flywheel and must never see
  bead artifacts.

## bv --robot-* reference

**Never run bare `bv`** — with no flags it opens an interactive TUI and
blocks the session; every invocation needs a `--robot-*` flag. Flags:
`--robot-triage` (mega-command, see above), `--robot-next`,
`--robot-plan`, `--robot-priority`, `--robot-insights`,
`--robot-label-health`, `--robot-label-flow`, `--robot-label-attention`,
`--robot-history`, `--robot-diff --diff-since <ref>`,
`--robot-burndown`, `--robot-forecast`, `--robot-alerts`,
`--robot-suggest`, `--robot-graph [--graph-format=json|dot|mermaid]`,
`--export-graph <file.html>`. Scope any of these with `--label <name>`,
`--as-of <date>`, or `--recipe actionable|high-impact`.

## ntm (session multiplexer)

`ntm` is operator-facing — not for worker agents inside panes. If a
role needs to inspect or drive other sessions, the agent-usable robot
surface is `--robot-status`, `--robot-snapshot`, `--robot-context`,
`--robot-tail=SESSION`, `--robot-plan`, `--robot-dashboard`,
`--robot-terse`, `--robot-markdown` for inspection, and
`--robot-send`, `--robot-ack`, `--robot-spawn`,
`--robot-interrupt=SESSION` for control. The TUI surfaces (dashboard,
palette) are human-only. Robot exit codes: `0` success, `1` error, `2`
unavailable.

## agent-mail (file reservations + messaging)

MCP server coordinating concurrent agents on the same repo: register an
identity, reserve the files you're about to touch, message the agent
whose reservation blocks you instead of guessing or waiting silently.
Same-repo workflow: `ensure_project` → `register_agent` (with
`project_key` = absolute repo path, identity is your assigned agent
name — ntm already registered it) →
`file_reservation_paths` before editing anything → `send_message` with
a `thread_id` for anything expecting a reply → `fetch_inbox` /
`acknowledge_message` on the receiving end. Cross-repo mail needs
either a shared `project_key` (option A) or per-repo registration plus
an explicit cross-project reference (option B) — pick one convention
and don't mix them. Prefer the macros (`macro_start_session`,
`macro_prepare_thread`, `macro_file_reservation_cycle`,
`macro_contact_handshake`) over the granular calls when speed matters
or the caller is a smaller model — each macro collapses several
round-trips into one. Common pitfalls: `from_agent` not registered
(call `register_agent` before your first `send_message`) and
`FILE_RESERVATION_CONFLICT` (someone already holds the file — message
them, don't force it). Full tool surface: identity
`ensure_project`/`register_agent`/`whois`/`create_agent_identity`/
`list_agents`/`resolve_pane_identity`; messaging
`send_message`/`reply_message`/`fetch_inbox`/`mark_message_read`/
`acknowledge_message`/`search_messages`/`summarize_thread`;
reservations
`file_reservation_paths`/`check_file_reservation_conflicts`/
`release_file_reservations`/`renew_file_reservations`/
`force_release_file_reservation`/`install_precommit_guard`;
contacts `list_contacts`/`request_contact`/`respond_contact`/
`set_contact_policy`; build slots
`acquire_build_slot`/`renew_build_slot`/`release_build_slot`.

Thread mail to work: when a message concerns a specific issue, use the
issue id (`br-###` — never the legacy `bd-###`) as the `thread_id`,
prefix the subject with it, and give any related file reservation a
`reason` naming the same id, so mail and the bead board point at one
unit of work.

## ubs

Golden rule: run `ubs <changed-files>` before every commit. Exit `0`
means safe to commit; exit `>0` means fix and re-run — don't commit
past a nonzero exit. Output is `file:line:col` with severity tiers
Critical / Important / Contextual; clear Critical and Important before
committing. Two anti-patterns to avoid: don't full-scan the repo on
every edit (scope it to the files just touched), and don't patch
around a finding — fix the root cause it's pointing at.

## dcg

Hook that intercepts destructive shell commands before they execute,
explains why the command is dangerous, and suggests a safer
alternative. A dcg deny arrives as a PreToolUse denial on the Bash
call — treat it like any other tool denial: stop, read the
explanation, and either take the suggested alternative or ask the
human. Do not retry the same command through different quoting or
escaping to route around a denial. Advisory, fail-open, and
Claude-Code-only — Codex agents are unguarded; do not treat this as a
security boundary.

## cass

Searches past agent session transcripts for prior work, decisions, or
context — reach for it before re-deriving something a session already
figured out. Invoke via `cass --robot --json <query>`; an optional
semantic model changes ranking quality, not the interface.
