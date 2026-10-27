import type { ExtensionAPI } from "@oh-my-pi/pi-coding-agent"

export default function openrouterRouting(pi: ExtensionAPI) {
  pi.on("before_provider_request", (event, ctx) => {
    if (ctx.model?.provider !== "openrouter" || ctx.model.id !== "deepseek/deepseek-v4.1-flash") return

    // Plain provider sorting does not opt into Nitro's priority endpoints.
    const payload = event.payload as Record<string, unknown>
    const provider = payload.provider as Record<string, unknown> | undefined
    return { ...payload, provider: { ...provider, sort: "throughput" } }
  })
}
