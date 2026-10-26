import { Plugin } from "@opencode/plugin"

// macOS power primitive: "user is active" + "no idle sleep" assertions held
// for a fixed window. This is what a keypress does — it holds off idle
// system sleep, display sleep, and the screensaver idle timer that profile
// controls enforce. Assertions expire on their own, so idleness never needs
// cleanup, and a crashed agent leaves at most one lapsing timer behind.
const CAFFEINATE = "/usr/bin/caffeinate"
// A turn survives silent gaps up to this long (e.g. a tool that streams
// nothing); the same value is the sleep tail after the last work signal.
const ASSERTION_SECONDS = 300
// Work signals arrive in bursts (every streamed chunk); spawn at most one
// caffeinate per window.
const MIN_REFRESH_MS = 30_000

// Keep the machine awake only while an agent is actually taking a turn.
// Refresh sources are signals that exist solely during real work: agent-loop
// model dispatches, tool execution, and streamed message parts. An idle
// session — open TUI, waiting pane, stopped swarm — spawns nothing, and the
// last assertion simply lapses. -u wakes a sleeping display; that
// is the price of suppressing profile-forced screensavers mid-turn.
// Non-darwin hosts load this plugin inert.
export default Plugin.define({
  id: "caffeinate",
  async setup(ctx) {
    if (process.platform !== "darwin") return

    let lastSpawn = 0
    const refresh = () => {
      const now = Date.now()
      if (now - lastSpawn < MIN_REFRESH_MS) return
      lastSpawn = now
      Bun.spawn([CAFFEINATE, "-u", "-i", "-t", String(ASSERTION_SECONDS)], {
        stdout: "ignore",
        stderr: "ignore",
      }).unref()
    }

    // Immediately before each agent-loop model request — turn start and
    // every continuation after a tool result.
    await ctx.session.hook("context", () => refresh())
    // Tool start covers dispatch-free stretches like long-running commands.
    await ctx.tool.hook("execute.before", () => refresh())

    // Streamed parts (text, reasoning, live tool output) cover long gaps
    // between dispatches. Prefix match so event-type renames degrade to
    // fewer refreshes instead of none. User admissions count too; harmless,
    // a turn follows immediately.
    const controller = new AbortController()
    void (async () => {
      try {
        for await (const event of ctx.event.subscribe({ signal: controller.signal }) as any) {
          if (typeof event?.type === "string" && event.type.startsWith("message.")) refresh()
        }
      } catch {}
    })()
    return () => controller.abort()
  },
})
