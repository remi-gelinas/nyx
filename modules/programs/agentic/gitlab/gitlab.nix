{
  flake.modules.homeManager.gitlab =
    let
      # GitLab's hosted MCP server. It authenticates with OAuth through dynamic
      # client registration, so no token lives in the config; each harness
      # runs the browser sign-in on first connect.
      url = "https://gitlab.com/api/v4/mcp";
    in
    {
      programs.opencode.settings.mcp.servers.gitlab = {
        type = "remote";
        inherit url;
      };
      programs.omp.mcpServers.gitlab = {
        type = "http";
        inherit url;
      };
    };
}
