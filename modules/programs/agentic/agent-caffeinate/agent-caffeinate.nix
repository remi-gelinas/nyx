{
  # Keep macOS awake only while an agent is actually taking a turn: the
  # plugin holds timed caffeinate assertions refreshed by real work
  # signals (model dispatches, tool execution, streamed parts) that expire
  # on their own, so an idle agent session never blocks sleep. opencode is
  # the current trigger source, not the feature's subject; other harnesses
  # can be added beside it. Composed alongside opencode by the aggregator
  # (like flywheel) — importing the aspect here would duplicate the
  # opencode module. The plugin no-ops off darwin, so hosts inheriting
  # this config install it inert.
  flake.modules.homeManager.agent-caffeinate = {
    programs.opencode.settings.plugins = [ "${./_opencode-plugin}" ];
  };
}
