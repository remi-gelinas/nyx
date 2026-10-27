import type { ExtensionAPI } from "@oh-my-pi/pi-coding-agent"
import { spawnSync } from "node:child_process"
import { mkdirSync, writeFileSync } from "node:fs"
import { homedir } from "node:os"
import { join } from "node:path"

export default function codebaseMemory(pi: ExtensionAPI) {
  pi.on("session_start", (_event, ctx) => {
    if (ctx.agent.kind !== "main") return
    try {
      const stateDir = join(process.env.XDG_STATE_HOME ?? join(homedir(), ".local", "state"), "omp")
      mkdirSync(stateDir, { recursive: true })
      writeFileSync(
        join(stateDir, "codebase-memory-plugin.alive"),
        JSON.stringify({ id: "codebase-memory", pid: process.pid, ts: new Date().toISOString() }),
      )
    } catch {}
  })

  pi.on("tool_result", (event, ctx) => {
    if (event.isError || (event.toolName !== "grep" && event.toolName !== "glob")) return
    // OMP glob puts semicolon-delimited patterns in `path`.
    // hook-augment expects Claude's Glob { pattern } / Grep { pattern, path }.
    const inputs = event.toolName === "glob"
      ? String(event.input.path ?? "**/*").split(";").map(pattern => ({ pattern: pattern.trim() })).filter(input => input.pattern)
      : [event.input]
    const extras: string[] = []
    for (const input of inputs) {
      try {
        const res = spawnSync("codebase-memory-mcp", ["hook-augment"], {
          input: JSON.stringify({
            tool_name: event.toolName === "grep" ? "Grep" : "Glob",
            tool_input: input,
            cwd: ctx.cwd,
          }),
          encoding: "utf8",
          timeout: 5_000,
        })
        if (res.error || res.status !== 0) continue
        let extra = res.stdout?.trim()
        try {
          extra = JSON.parse(extra)?.hookSpecificOutput?.additionalContext ?? extra
        } catch {}
        if (typeof extra === "string" && extra && !extras.includes(extra)) extras.push(extra)
      } catch {}
    }
    // Graph source is tool output, not trusted developer instructions.
    if (extras.length) return { content: [...event.content, { type: "text", text: extras.join("\n\n") }] }
  })
}
