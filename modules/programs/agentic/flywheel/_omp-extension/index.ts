import type { ExtensionAPI } from "@oh-my-pi/pi-coding-agent"
import { spawnSync } from "node:child_process"
import { existsSync, mkdirSync, writeFileSync } from "node:fs"
import { homedir, userInfo } from "node:os"
import { join, resolve } from "node:path"

const MAIL_URL = "http://127.0.0.1:8765/mcp/"
const READ_TOOLS = new Set(["read", "grep", "glob", "ast_grep", "web_search", "yield"])
const GRAPH_READ_TOOLS = new Set([
  "search_graph", "search_code", "trace_path", "detect_changes", "get_code_snippet",
  "get_architecture", "get_graph_schema", "list_projects", "index_status",
])

export default function flywheel(pi: ExtensionAPI) {
  const agentName = process.env.AGENT_NAME
  let isSwarm = false
  try {
    isSwarm = !!agentName && agentName !== userInfo().username
  } catch {}

  pi.on("session_start", (_event, ctx) => {
    if (ctx.agent.kind !== "main") return
    try {
      const stateDir = join(process.env.XDG_STATE_HOME ?? join(homedir(), ".local", "state"), "omp")
      mkdirSync(stateDir, { recursive: true })
      writeFileSync(
        join(stateDir, "flywheel-plugin.alive"),
        JSON.stringify({ id: "flywheel", pid: process.pid, swarm: isSwarm, ts: new Date().toISOString() }),
      )
    } catch {}
  })

  // Helpers share their parent's process environment, not its mail identity.
  // Keep them read-only; independent writers belong in separate NTM panes.
  pi.on("before_agent_start", (event, ctx) => {
    const identity = ctx.agent.kind === "sub"
      ? "You are a read-only helper. Do not claim beads, register mail identities, reserve files, or write changes. " +
        "Return findings to your parent. Its AGENT_NAME environment variable is not your identity."
      : isSwarm
        ? `You are agent ${agentName} — the identity ntm assigned this pane. ` +
          `Use exactly ${agentName} in every mail call, file reservation, and br --actor. ` +
          `If you call register_agent, pass name=${agentName}; never auto-generate another identity.`
        : undefined
    if (identity) return { systemPrompt: [...event.systemPrompt, identity] }
  })

  pi.on("tool_call", (event, ctx) => {
    if (ctx.agent.kind === "sub") {
      const tool = pi.getAllTools().find(tool => tool.name === event.toolName)
      const graphRead = tool?.mcpServerName === "codebase-memory" && GRAPH_READ_TOOLS.has(tool.mcpToolName ?? "")
      if (!READ_TOOLS.has(event.toolName) && !graphRead) {
        return { block: true, reason: "Read-only helper: return findings to your parent instead of changing state." }
      }
    }
    if (event.toolName !== "bash") return
    const command = event.input.command
    if (typeof command !== "string" || !command) return
    const cwd = typeof event.input.cwd === "string"
      ? resolve(ctx.cwd, event.input.cwd.replace(/^~(?=\/|$)/, homedir()))
      : ctx.cwd

    // DCG uses the same stdin protocol across harnesses. Unavailable or
    // malformed responses fail open, matching the OpenCode bridge.
    try {
      const res = spawnSync("dcg", [], {
        input: JSON.stringify({ tool_name: "Bash", tool_input: { command }, cwd }),
        encoding: "utf8",
        timeout: 3_000,
      })
      if (res.error) return
      let reason: string | undefined
      try {
        const out = JSON.parse(res.stdout || "{}")
        const decision = out?.hookSpecificOutput?.permissionDecision ?? out?.decision
        if (decision === "deny" || decision === "block") {
          reason = out?.hookSpecificOutput?.permissionDecisionReason ?? out?.reason ?? "destructive command"
        }
      } catch {}
      if (reason === undefined && res.status === 2) reason = res.stderr?.trim() || "destructive command"
      if (reason !== undefined) {
        return {
          block: true,
          reason: `dcg blocked this command: ${reason}. Do not retry through different quoting or escaping; take the suggested alternative or ask the human.`,
        }
      }
    } catch {}
  })

  pi.on("session_compact", (_event, ctx) => {
    if (!isSwarm || ctx.agent.kind !== "main") return
    pi.sendMessage({
      customType: "flywheel-compaction",
      content: "Context was just compacted. Read your global NYX.md operating rules and this repo's AGENTS.md now. " +
        "Briefly confirm the key rules before continuing.",
      display: false,
      attribution: "agent",
    }, { deliverAs: "nextTurn" })
  })

  pi.on("session_stop", async (event, ctx) => {
    if (!isSwarm || ctx.agent.kind !== "main" || event.signal.aborted) return
    const dir = ctx.cwd
    if (!existsSync(join(dir, ".beads"))) return
    const paused = () => existsSync(join(dir, ".beads", "flywheel-pause")) ||
      existsSync(join(dir, ".beads", `flywheel-pause-${agentName}`))
    if (paused()) return

    const ready = spawnSync("br", ["ready", "--json"], { cwd: dir, encoding: "utf8", timeout: 10_000 })
    let readyCount = 0
    try {
      const parsed = JSON.parse(ready.stdout || "[]")
      if (!ready.error && ready.status === 0 && Array.isArray(parsed)) readyCount = parsed.length
    } catch {}

    let reason: string | undefined
    if (readyCount > 0) {
      reason = `The bead frontier has ${readyCount} ready item(s). Fetch your agent-mail inbox and handle pending mail, ` +
        "then claim the next bead per the claim protocol: br ready --json, br update --claim, announce over mail, reserve files. " +
        "Stop only when the frontier is empty and your inbox is clear."
    } else {
      let pending = 0
      for (const view of ["ack-required", "urgent-unread"]) {
        try {
          const res = await fetch(MAIL_URL, {
            method: "POST",
            headers: { "Content-Type": "application/json", Accept: "application/json, text/event-stream" },
            body: JSON.stringify({
              jsonrpc: "2.0", id: 1, method: "resources/read",
              params: { uri: `resource://views/${view}/${agentName}?project=${encodeURIComponent(dir)}` },
            }),
            signal: AbortSignal.any([event.signal, AbortSignal.timeout(5_000)]),
          })
          const body = await res.json()
          const count = JSON.parse(body?.result?.contents?.[0]?.text ?? "{}")?.count
          if (typeof count === "number") pending += count
        } catch {}
      }
      if (pending > 0) reason = `Your agent-mail inbox has ${pending} message(s) needing attention. ` +
        "Fetch your inbox, acknowledge and act on each, then re-check the frontier."
    }

    // Explicit blocks are not subject to OMP's eight advisory-continuation cap.
    // The operator can still interrupt or drop a pause sentinel at any time.
    if (reason && !event.signal.aborted && !paused()) return { decision: "block", reason }
  })
}
