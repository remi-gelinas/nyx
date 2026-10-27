import { afterEach, beforeEach, describe, expect, mock, spyOn, test } from "bun:test"
import * as childProcess from "node:child_process"
import * as fs from "node:fs"
import { userInfo } from "node:os"
import flywheel from "./index"

const originalAgent = process.env.AGENT_NAME
const originalFetch = globalThis.fetch
let spawn: ReturnType<typeof spyOn>

beforeEach(() => {
  process.env.AGENT_NAME = "BlueLake"
  spawn = spyOn(childProcess, "spawnSync").mockReturnValue({ status: 0, stdout: "[]" } as any)
  spyOn(fs, "existsSync").mockImplementation(path => String(path).endsWith("/.beads"))
  spyOn(fs, "mkdirSync").mockImplementation(() => undefined)
  spyOn(fs, "writeFileSync").mockImplementation(() => undefined)
  globalThis.fetch = mock(async () => Response.json({ result: { contents: [{ text: '{"count":0}' }] } })) as any
})

afterEach(() => {
  mock.restore()
  globalThis.fetch = originalFetch
  if (originalAgent === undefined) delete process.env.AGENT_NAME
  else process.env.AGENT_NAME = originalAgent
})

function harness(kind = "main") {
  const handlers: Record<string, Function> = {}
  const pi = {
    on: (name: string, handler: Function) => { handlers[name] = handler },
    sendMessage: mock(),
    getAllTools: () => [
      { name: "graph_query", mcpServerName: "codebase-memory", mcpToolName: "search_graph" },
      { name: "graph_write", mcpServerName: "codebase-memory", mcpToolName: "delete_project" },
    ],
  }
  flywheel(pi as any)
  const ctx = { cwd: "/repo", agent: { kind } }
  const stop = () => handlers.session_stop({ signal: new AbortController().signal, stop_hook_active: true }, ctx)
  return { handlers, pi, ctx, stop }
}

describe("flywheel continuation", () => {
  test("blocks beyond eight stop passes while ready work remains", async () => {
    spawn.mockReturnValue({ status: 0, stdout: '[{"id":"task"}]' })
    const { stop } = harness()
    for (let i = 0; i < 10; i++) expect(await stop()).toMatchObject({ decision: "block" })
    expect(globalThis.fetch).not.toHaveBeenCalled()
  })

  test("allows completion with no ready work or important mail", async () => {
    expect(await harness().stop()).toBeUndefined()
    expect(globalThis.fetch).toHaveBeenCalledTimes(2)
  })

  test("important mail prevents completion", async () => {
    globalThis.fetch = mock(async () => Response.json({ result: { contents: [{ text: '{"count":1}' }] } })) as any
    expect(await harness().stop()).toMatchObject({ decision: "block", reason: expect.stringContaining("2 message(s)") })
    const request = JSON.parse((globalThis.fetch as any).mock.calls[0][1].body)
    expect(request.params.uri).toContain("project=%2Frepo")
  })

  test("global and per-agent pause sentinels allow completion", async () => {
    for (const sentinel of ["flywheel-pause", "flywheel-pause-BlueLake"]) {
      spyOn(fs, "existsSync").mockImplementation(path => String(path).endsWith("/.beads") || String(path).endsWith(`/${sentinel}`))
      expect(await harness().stop()).toBeUndefined()
    }
    expect(spawn).not.toHaveBeenCalled()
  })

  test("interactive sessions, helpers, and interrupted turns do not loop", async () => {
    expect(await harness("sub").stop()).toBeUndefined()
    process.env.AGENT_NAME = userInfo().username
    expect(await harness().stop()).toBeUndefined()
    process.env.AGENT_NAME = "BlueLake"
    const { handlers, ctx } = harness()
    expect(await handlers.session_stop({ signal: AbortSignal.abort() }, ctx)).toBeUndefined()
    expect(spawn).not.toHaveBeenCalled()
  })

  test("unavailable frontier and mail services fail open", async () => {
    spawn.mockReturnValue({ error: new Error("missing br"), stdout: "bad json" })
    globalThis.fetch = mock(async () => { throw new Error("offline") }) as any
    expect(await harness().stop()).toBeUndefined()
  })
})

test("DCG blocks both protocol denials and exit-code denials", () => {
  const { handlers, ctx } = harness()
  for (const result of [
    { status: 0, stdout: '{"hookSpecificOutput":{"permissionDecision":"deny","permissionDecisionReason":"unsafe"}}' },
    { status: 0, stdout: '{"decision":"block"}' },
    { status: 2, stdout: "", stderr: "unsafe" },
  ]) {
    spawn.mockReturnValue(result)
    expect(handlers.tool_call({ toolName: "bash", input: { command: "dangerous-command" } }, ctx)).toMatchObject({ block: true })
  }
  expect(JSON.parse(spawn.mock.calls[0][2].input)).toMatchObject({ tool_name: "Bash", cwd: "/repo" })
})

test("DCG ignores other tools and fails open when unavailable", () => {
  const { handlers, ctx } = harness()
  expect(handlers.tool_call({ toolName: "read", input: {} }, ctx)).toBeUndefined()
  expect(spawn).not.toHaveBeenCalled()
  spawn.mockReturnValue({ error: new Error("missing dcg") })
  expect(handlers.tool_call({ toolName: "bash", input: { command: "git status" } }, ctx)).toBeUndefined()
})

test("DCG checks the bash call's working directory", () => {
  const { handlers, ctx } = harness()
  handlers.tool_call({ toolName: "bash", input: { command: "git status", cwd: "subdir" } }, ctx)
  expect(JSON.parse(spawn.mock.calls[0][2].input).cwd).toBe("/repo/subdir")
})

test("helpers cannot mutate files, run shells, or borrow the parent's mail identity", () => {
  const { handlers, ctx, pi } = harness("sub")
  for (const toolName of ["write", "edit", "bash", "eval", "task", "graph_write", "mcp__mcp_agent_mail_register_agent"]) {
    expect(handlers.tool_call({ toolName, input: {} }, ctx)).toMatchObject({ block: true })
  }
  for (const toolName of ["read", "grep", "glob", "yield", "graph_query"]) {
    expect(handlers.tool_call({ toolName, input: {} }, ctx)).toBeUndefined()
  }
  const result = handlers.before_agent_start({ systemPrompt: ["base"] }, ctx)
  expect(result.systemPrompt).toEqual(["base", expect.stringContaining("not your identity")])
  handlers.session_start({}, ctx)
  handlers.session_compact({}, ctx)
  expect(fs.writeFileSync).not.toHaveBeenCalled()
  expect(pi.sendMessage).not.toHaveBeenCalled()
})

test("main sessions get the pane identity and a passive compaction reminder", () => {
  const { handlers, ctx, pi } = harness()
  expect(handlers.before_agent_start({ systemPrompt: ["base"] }, ctx).systemPrompt).toEqual([
    "base", expect.stringContaining("You are agent BlueLake"),
  ])
  handlers.session_start({}, ctx)
  expect(fs.writeFileSync).toHaveBeenCalledTimes(1)
  handlers.session_compact({}, ctx)
  expect(pi.sendMessage).toHaveBeenCalledWith(expect.objectContaining({ content: expect.stringContaining("NYX.md") }), { deliverAs: "nextTurn" })
})
