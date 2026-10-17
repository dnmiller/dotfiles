// opencode 2 plugin: tell cursor-api-proxy which Cursor mode to run each
// request in, based on the active opencode agent. opencode 2 ignores
// agents.<name>.request.body, so the mode travels as the proxy's
// X-Cursor-Mode header instead (set on the "model.request" hook, which only
// fires for the "cursor-proxy" provider; the "cursor" provider from
// cursor-opencode-provider follows the agent on its own).
//
//   primary request, agent "plan" -> plan
//   primary request, agent "ask"  -> ask
//   primary request, any other    -> agent  (build, subagents, custom agents)
//   title / compaction / generate -> ask    (no tools needed)
const PROVIDER_ID = "cursor-proxy"
const AGENT_MODES = { plan: "plan", ask: "ask" }

export function cursorMode(event) {
  if (event.kind && event.kind !== "primary") return "ask"
  return AGENT_MODES[event.agent] ?? "agent"
}

export default {
  id: "dotfiles.cursor-mode",
  setup: async (ctx) => {
    const registration = await ctx.session.hook(
      "model.request",
      (event) => {
        event.headers = { ...event.headers, "x-cursor-mode": cursorMode(event) }
      },
      { providerID: PROVIDER_ID },
    )
    return () => registration.dispose()
  },
}
