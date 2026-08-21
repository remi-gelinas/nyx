{ self, ... }:
{
  flake.modules.homeManager.agentic.imports = with self.modules.homeManager; [
    claude-code
    codebase-memory
    flywheel
  ];
}
