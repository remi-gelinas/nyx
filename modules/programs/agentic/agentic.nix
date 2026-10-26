{ self, ... }:
{
  flake.modules.homeManager.agentic.imports = with self.modules.homeManager; [
    codebase-memory
    flywheel
    opencode
    agent-caffeinate
  ];
}
