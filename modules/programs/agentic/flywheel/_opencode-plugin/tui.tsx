/** @jsxImportSource @opentui/solid */
import { Plugin } from "@opencode/plugin/tui"
import { userInfo } from "node:os"

// Same swarm test as the server part: interactive shells set AGENT_NAME to
// the username, which is not a swarm identity.
const agentName = process.env.AGENT_NAME
const isSwarm = (() => {
  try {
    return !!agentName && agentName !== userInfo().username
  } catch {
    return false
  }
})()

export default Plugin.define({
  id: "flywheel.tui",
  setup(context) {
    if (!isSwarm) return
    return context.ui.slot({
      append: "prompt.footer.status",
      render: () => <text fg={context.theme.text.base}>{agentName}</text>,
    })
  },
})
