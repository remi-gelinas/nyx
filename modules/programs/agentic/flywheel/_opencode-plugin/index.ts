import { Plugin } from "@opencode/plugin"
import { spawnSync } from "node:child_process"
import { existsSync, mkdirSync, writeFileSync } from "node:fs"
import { homedir, userInfo } from "node:os"
import { join } from "node:path"

// Same literal agent-mail.nix pins; the server binds loopback only.
const MAIL_URL = "http://127.0.0.1:8765/mcp/"
// An idle fired this soon after our own nudge is the nudge's own echo, not
// the agent finishing work.
const NUDGE_COOLDOWN_MS = 15_000

const loopDirective = (n: number) =>
  `The bead frontier has ${n} ready item(s); the flywheel loop is not done. ` +
  `Fetch your agent-mail inbox and handle anything pending, then claim the next bead per the claim protocol ` +
  `(br ready --json or bv --robot-next, br update --claim, announce over mail, reserve files) and work it. ` +
  `Stop only when the frontier is empty and your inbox is clear.`

const mailDirective = (n: number) =>
  `Your agent-mail inbox has ${n} message(s) needing attention (ack-required or urgent). ` +
  `Fetch your inbox, acknowledge and act on each — a blocked peer may be waiting on you. ` +
  `Then re-check the frontier; stop only when it is empty and nothing awaits your ack.`

const identityLine = (name: string) =>
  `You are agent ${name} — the identity ntm assigned this pane. agent-mail already has this name registered ` +
  `and AGENT_NAME/BR_ACTOR are exported in your environment. Use exactly this name everywhere: register_agent ` +
  `(an idempotent profile update — pass name=${name}), every mail call, file reservations, and br --actor. ` +
  `Never omit the name or let one be auto-generated.`

const COMPACT_REMINDER =
  `🚨 IMPORTANT: Context was just compacted. STOP. You MUST:\n` +
  `1. Read AGENTS.md NOW\n` +
  `2. Confirm by briefly stating what key rules/conventions you found\n\n` +
  `Do not proceed with any task until you have read the file and confirmed what you learned.`

// Swarm panes only: the launch wrapper exports AGENT_NAME; interactive
// shells set it to the username, which is not a swarm identity.
const agentName = process.env.AGENT_NAME
const isSwarm = (() => {
  try {
    return !!agentName && agentName !== userInfo().username
  } catch {
    return false
  }
})()

const attentionCount = async (view: string, project: string): Promise<number> => {
  const res = await fetch(MAIL_URL, {
    method: "POST",
    headers: {
      "Content-Type": "application/json",
      Accept: "application/json, text/event-stream",
    },
    body: JSON.stringify({
      jsonrpc: "2.0",
      id: 1,
      method: "resources/read",
      params: { uri: `resource://views/${view}/${agentName}?project=${project}` },
    }),
    signal: AbortSignal.timeout(5_000),
  })
  const body = await res.json()
  try {
    const count = JSON.parse(body?.result?.contents?.[0]?.text ?? "{}")?.count
    return typeof count === "number" ? count : 0
  } catch {
    return 0
  }
}

export default Plugin.define({
  id: "flywheel",
  setup(ctx) {
    // Plugin load failure in v2 is a quiet WARN; this sentinel is what lets
    // ntm/doctor checks distinguish "loop armed" from "silently dead".
    try {
      const stateDir = join(homedir(), ".local", "state", "opencode")
      mkdirSync(stateDir, { recursive: true })
      writeFileSync(
        join(stateDir, "flywheel-plugin.alive"),
        JSON.stringify({ id: "flywheel", pid: process.pid, swarm: isSwarm, ts: new Date().toISOString() }),
      )
    } catch {}

    // dcg bridge: dcg has no opencode support, but its stdin protocol is
    // harness-agnostic Claude hook JSON. Deny by throwing — the model sees
    // the explanation. Advisory and fail-open, like every dcg integration.
    ctx.tool.hook("execute.before", (event: any) => {
      try {
        if (event?.tool !== "bash" && event?.tool !== "shell") return
        const command = event?.input?.command ?? event?.args?.command
        if (typeof command !== "string" || command.length === 0) return
        const dir = ctx.location?.directory ?? process.cwd()
        const res = spawnSync("dcg", [], {
          input: JSON.stringify({ tool_name: "Bash", tool_input: { command }, cwd: dir }),
          encoding: "utf8",
          timeout: 3_000,
        })
        if (res.error) return
        let reason: string | undefined
        try {
          const out = JSON.parse(res.stdout || "{}")
          const decision = out?.hookSpecificOutput?.permissionDecision ?? out?.decision
          if (decision === "deny" || decision === "block") {
            reason = out?.hookSpecificOutput?.permissionDecisionReason ?? out?.reason
          }
        } catch {}
        if (reason === undefined && res.status === 2) reason = res.stderr?.trim()
        if (reason !== undefined) {
          throw new Error(`dcg blocked this command: ${reason ?? "destructive command"}. Do not retry the same command through different quoting or escaping; take the suggested alternative or ask the human.`)
        }
      } catch (e) {
        if (e instanceof Error && e.message.startsWith("dcg blocked")) throw e
      }
    })

    if (!isSwarm) return

    const lastNudge = new Map<string, number>()

    const onIdle = async (sessionID: string) => {
      const dir = ctx.location?.directory ?? process.cwd()
      if (!existsSync(join(dir, ".beads"))) return
      // Operator pause sentinels; flywheel-pause/flywheel-resume manage them.
      if (existsSync(join(dir, ".beads", "flywheel-pause"))) return
      if (existsSync(join(dir, ".beads", `flywheel-pause-${agentName}`))) return
      const last = lastNudge.get(sessionID) ?? 0
      if (Date.now() - last < NUDGE_COOLDOWN_MS) return

      const ready = spawnSync("br", ["ready", "--json"], { cwd: dir, encoding: "utf8", timeout: 10_000 })
      let readyCount = 0
      try {
        const parsed = JSON.parse(ready.stdout || "[]")
        readyCount = Array.isArray(parsed) ? parsed.length : 0
      } catch {}
      if (readyCount > 0) {
        lastNudge.set(sessionID, Date.now())
        await ctx.session.prompt({ sessionID, text: loopDirective(readyCount) })
        return
      }

      // Frontier empty — ack-required or urgent mail still keeps the loop
      // alive; plain FYI mail deliberately does not, or swarms never sleep.
      let pending = 0
      for (const view of ["ack-required", "urgent-unread"]) {
        try {
          pending += await attentionCount(view, dir)
        } catch {}
      }
      if (pending > 0) {
        lastNudge.set(sessionID, Date.now())
        await ctx.session.prompt({ sessionID, text: mailDirective(pending) })
      }
    }

    const controller = new AbortController()
    void (async () => {
      try {
        for await (const event of ctx.event.subscribe({ signal: controller.signal }) as any) {
          try {
            const type = event?.type ?? ""
            const sessionID = event?.properties?.sessionID ?? event?.sessionID
            if (!sessionID) continue
            if (type === "session.created") {
              // The model never sees env vars; without this line agents call
              // register_agent bare and mint a second identity split from
              // their own reservations.
              await ctx.session.synthetic({ sessionID, text: identityLine(agentName!) })
            } else if (type === "session.compacted") {
              await ctx.session.synthetic({ sessionID, text: COMPACT_REMINDER })
            } else if (type === "session.idle") {
              await onIdle(sessionID)
            }
          } catch {}
        }
      } catch {}
    })()

    return () => controller.abort()
  },
})
