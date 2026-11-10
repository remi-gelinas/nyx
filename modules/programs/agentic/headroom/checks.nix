{ inputs, self, ... }:
{
  perSystem =
    { pkgs, lib, ... }:
    let
      home = inputs.home-manager.lib.homeManagerConfiguration {
        inherit pkgs;
        modules = [ self.modules.homeManager.remi ];
      };
      cfg = home.config;
      headroom = lib.findFirst (p: (p.pname or "") == "headroom-ai") null cfg.home.packages;
      proxy = cfg.launchd.agents.headroom.config;
      proxyUrl = cfg.programs.opencode.settings.providers.openrouter.settings.baseURL;
      # Applications carry no pythonModule; their libraries do.
      python = (builtins.head headroom.dependencies).pythonModule;
      pythonEnv = python.withPackages (_: headroom.dependencies);
    in
    {
      # Both harnesses must reach OpenRouter through the same proxy, and the
      # package must compress with every network path closed.
      checks.headroom =
        assert headroom != null;
        assert builtins.head proxy.ProgramArguments == lib.getExe headroom;
        assert lib.hasPrefix "http://127.0.0.1:" proxyUrl;
        assert cfg.programs.omp.models.providers.openrouter.baseUrl == proxyUrl;
        assert cfg.programs.omp.models.providers.openrouter.api == "openrouter";
        assert cfg.programs.omp.models.providers.openrouter ? apiKey;
        assert
          cfg.programs.opencode.settings.mcp.servers.headroom.command == [
            (lib.getExe headroom)
            "mcp"
            "serve"
          ];
        assert cfg.programs.omp.mcpServers.headroom.command == lib.getExe headroom;
        pkgs.runCommand "headroom" { } ''
          export HOME=$TMPDIR HEADROOM_OFFLINE=1
          ${lib.getExe headroom} --version
          PYTHONPATH=${headroom}/${python.sitePackages} ${pythonEnv.interpreter} ${pkgs.writeText "smoke.py" ''
            from headroom import compress

            log = "\n".join(f"INFO step {i} ok" for i in range(3000)) + "\nFATAL disk full"
            result = compress(
                [
                    {"role": "user", "content": "What failed?"},
                    {"role": "assistant", "content": None, "tool_calls": [
                        {"id": "c1", "type": "function", "function": {"name": "logs", "arguments": "{}"}}
                    ]},
                    {"role": "tool", "tool_call_id": "c1", "content": log},
                ],
                model="gpt-4o",
            )
            assert result.tokens_after < result.tokens_before // 10, result
            assert "FATAL disk full" in str(result.messages)
          ''}
          touch $out
        '';
    };
}
