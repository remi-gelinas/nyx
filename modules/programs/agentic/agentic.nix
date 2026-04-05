{ self, ... }:
{
  flake.modules.homeManager.agentic.imports = with self.modules.homeManager; [
    claude-code
    agent-orchestration
    cliproxyapi
    rtk
    practical-skills
  ];
}
