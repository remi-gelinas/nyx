{
  flake.modules.homeManager.claude-code-zed =
    {
      config,
      lib,
      pkgs,
      ...
    }:
    {
      programs.zed-editor.userSettings.agent_servers."Claude Code" = {
        type = "custom";
        command = lib.getExe pkgs.master.claude-agent-acp;
        # finalPackage is the Home Manager wrapper, so plugins, skills, and
        # MCP servers apply inside Zed too.
        env.CLAUDE_CODE_EXECUTABLE = lib.getExe config.programs.claude-code.finalPackage;
      };
    };
}
