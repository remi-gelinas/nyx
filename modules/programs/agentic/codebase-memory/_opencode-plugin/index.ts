import { Plugin } from "@opencode/plugin"
import { spawnSync } from "node:child_process"
import { mkdirSync, writeFileSync } from "node:fs"
import { homedir } from "node:os"
import { join } from "node:path"

// hook-augment speaks Claude hook JSON on stdin and prints graph context for
// the search; it never blocks and exits 0 silently on any failure. Tool names
// are synthesized to the Claude spelling the binary expects.
const CLAUDE_TOOL: Record<string, string> = { grep: "Grep", glob: "Glob" }

export default Plugin.define({
  id: "codebase-memory",
  setup(ctx) {
    // Plugin load failure in v2 is a quiet WARN; the sentinel makes it
    // checkable.
    try {
      const stateDir = join(homedir(), ".local", "state", "opencode")
      mkdirSync(stateDir, { recursive: true })
      writeFileSync(
        join(stateDir, "codebase-memory-plugin.alive"),
        JSON.stringify({ id: "codebase-memory", pid: process.pid, ts: new Date().toISOString() }),
      )
    } catch {}

    ctx.tool.hook("execute.after", (event: any) => {
      try {
        const toolName = CLAUDE_TOOL[event?.tool]
        if (!toolName || event?.status === "error") return
        const res = spawnSync("codebase-memory-mcp", ["hook-augment"], {
          input: JSON.stringify({
            tool_name: toolName,
            tool_input: event?.input ?? event?.args ?? {},
            cwd: ctx.location?.directory ?? process.cwd(),
          }),
          encoding: "utf8",
          timeout: 5_000,
        })
        if (res.error || res.status !== 0) return
        let extra = res.stdout?.trim()
        try {
          extra = JSON.parse(extra)?.hookSpecificOutput?.additionalContext ?? extra
        } catch {}
        if (extra && typeof event?.output === "string") {
          event.output = `${event.output}\n\n${extra}`
        }
      } catch {}
    })
  },
})
