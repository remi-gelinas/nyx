import { expect, test } from "bun:test"
import openrouterRouting from "./index"

let handler: Function
openrouterRouting({ on: (event: string, callback: Function) => {
  expect(event).toBe("before_provider_request")
  handler = callback
} } as any)

const ctx = { model: { provider: "openrouter", id: "deepseek/deepseek-v4.1-flash" } }

test("adds plain throughput sorting without changing the model or requesting a service tier", () => {
  const payload = { model: ctx.model.id, stream: true, input: [{ role: "user", content: "hello" }] }
  const result = handler({ payload }, ctx)
  expect(result).toEqual({ ...payload, provider: { sort: "throughput" } })
  expect(result.model).not.toContain(":nitro")
  expect(result).not.toHaveProperty("service_tier")
  expect(payload).not.toHaveProperty("provider")
})

test("preserves other provider preferences and replaces only the sorting strategy", () => {
  const payload = {
    model: ctx.model.id,
    provider: { sort: "price", allow_fallbacks: true, data_collection: "deny", ignore: ["example"] },
  }
  expect(handler({ payload }, ctx)).toEqual({
    ...payload,
    provider: { ...payload.provider, sort: "throughput" },
  })
  expect(payload.provider.sort).toBe("price")
})

test("does not change other models, other providers, or sessions without a model", () => {
  for (const model of [
    { provider: "openrouter", id: "z-ai/glm-5.3-flash" },
    { provider: "deepseek", id: "deepseek/deepseek-v4.1-flash" },
    undefined,
  ]) {
    expect(handler({ payload: { model: "unchanged" } }, { model })).toBeUndefined()
  }
})
