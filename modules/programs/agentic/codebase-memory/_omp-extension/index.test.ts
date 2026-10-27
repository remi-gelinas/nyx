import { afterEach, beforeEach, expect, mock, spyOn, test } from "bun:test"
import * as childProcess from "node:child_process"
import codebaseMemory from "./index"

let spawn: ReturnType<typeof spyOn>
const handlers: Record<string, Function> = {}
const ctx = { cwd: "/repo" }

beforeEach(() => {
  spawn = spyOn(childProcess, "spawnSync").mockReturnValue({ status: 0, stdout: "graph context" } as any)
  codebaseMemory({ on: (name: string, handler: Function) => { handlers[name] = handler } } as any)
})
afterEach(() => mock.restore())

test("grep augmentation preserves original content and uses the session cwd", () => {
  const content = [{ type: "text", text: "matches" }]
  expect(handlers.tool_result({ toolName: "grep", input: { pattern: "foo", path: "src" }, content }, ctx)).toEqual({
    content: [...content, { type: "text", text: "graph context" }],
  })
  expect(JSON.parse(spawn.mock.calls[0][2].input)).toEqual({ tool_name: "Grep", tool_input: { pattern: "foo", path: "src" }, cwd: "/repo" })
})

test("glob paths become Claude patterns, including multiple paths", () => {
  const result = handlers.tool_result({ toolName: "glob", input: { path: "src/*.ts; test/*.ts" }, content: [] }, ctx)
  expect(spawn).toHaveBeenCalledTimes(2)
  expect(JSON.parse(spawn.mock.calls[0][2].input).tool_input).toEqual({ pattern: "src/*.ts" })
  expect(JSON.parse(spawn.mock.calls[1][2].input).tool_input).toEqual({ pattern: "test/*.ts" })
  expect(result.content).toEqual([{ type: "text", text: "graph context" }])
})

test("extracts hook JSON into tool content, never privileged additionalContext", () => {
  spawn.mockReturnValue({ status: 0, stdout: '{"hookSpecificOutput":{"additionalContext":"source text"}}' })
  expect(handlers.tool_result({ toolName: "glob", input: { path: "*.ts" }, content: [] }, ctx)).toEqual({
    content: [{ type: "text", text: "source text" }],
  })
})

test("ignores failed searches and unrelated tools", () => {
  expect(handlers.tool_result({ toolName: "grep", isError: true }, ctx)).toBeUndefined()
  expect(handlers.tool_result({ toolName: "read" }, ctx)).toBeUndefined()
  expect(spawn).not.toHaveBeenCalled()
})

test("augmentation failure leaves search output untouched", () => {
  for (const result of [{ error: new Error("unavailable") }, { status: 1 }, { status: 0, stdout: "" }]) {
    spawn.mockReturnValue(result)
    expect(handlers.tool_result({ toolName: "grep", input: { pattern: "foo" }, content: [] }, ctx)).toBeUndefined()
  }
})
