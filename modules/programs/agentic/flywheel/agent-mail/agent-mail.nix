{
  flake.modules.homeManager.flywheel =
    {
      pkgs,
      lib,
      config,
      ...
    }:
    let
      sources = import ./_sources.nix { inherit (pkgs) fetchFromGitHub; };
      riderLicense = import ../_rider-license.nix;
      ps = pkgs.python3Packages;

      # Both harnesses point at the same local HTTP transport. The service
      # binds 127.0.0.1 only and the server bypasses auth for localhost by
      # default (HTTP_ALLOW_LOCALHOST_UNAUTHENTICATED), so no bearer is set:
      # a shared secret here would have to be a world-readable store literal
      # for zero security gain over the loopback bind.
      mcpUrl = "http://127.0.0.1:8765/api/";

      pythonDeps = with ps; [
        aiolimiter
        aiosqlite
        attrs
        authlib
        bleach
        fastapi
        fastmcp
        filelock
        gitpython
        jinja2
        jsonschema
        litellm
        markdown2
        orjson
        pathspec
        pillow
        psutil
        pynacl
        python-decouple
        pyyaml
        redis
        rich
        sqlalchemy
        sqlmodel
        structlog
        tenacity
        tiktoken
        tinycss2
        typer
        uvicorn
      ];

      # Built from pinned source. Only the Python application is packaged:
      # upstream's installer also edits shell rc files and renames unrelated
      # binaries, which Nix has no business replicating.
      mcp-agent-mail = ps.buildPythonApplication {
        pname = "mcp-agent-mail";
        inherit (sources.mcp-agent-mail) version src;
        pyproject = true;

        build-system = [ ps.hatchling ];
        dependencies = pythonDeps;

        # Upstream caps authlib below 1.6; nixpkgs carries 1.7. Upstream also
        # lists its own linter among the runtime dependencies.
        pythonRelaxDeps = [ "authlib" ];
        pythonRemoveDeps = [ "ruff" ];

        doCheck = false;

        # Upstream declares no console script, so the CLI is reachable only as
        # a module; both serve-stdio and serve-http hang off this entry point.
        nativeBuildInputs = [ pkgs.makeWrapper ];
        postInstall = ''
          makeWrapper ${ps.python.interpreter} $out/bin/mcp-agent-mail \
            --add-flags "-m mcp_agent_mail.cli" \
            --prefix PYTHONPATH : "$out/${ps.python.sitePackages}:${ps.makePythonPath pythonDeps}"
        '';

        meta = {
          description = "Coordinated multi-agent messaging and coordination MCP server";
          homepage = "https://github.com/Dicklesworthstone/mcp_agent_mail";
          license = riderLicense // {
            url = "https://github.com/Dicklesworthstone/mcp_agent_mail/blob/v${sources.mcp-agent-mail.version}/LICENSE";
          };
          mainProgram = "mcp-agent-mail";
        };
      };
    in
    lib.mkMerge [
      {
        home.packages = [ mcp-agent-mail ];

        # Claude Code reaches the running service over the streamable HTTP
        # transport; no auth header since the server bypasses auth on the
        # loopback bind.
        programs.claude-code.mcpServers.mcp-agent-mail = {
          type = "http";
          url = mcpUrl;
        };

        # Codex reads MCP servers from ~/.codex/config.toml. Written verbatim
        # (not via a TOML generator) to keep any future top-level key ahead of
        # this section header — Codex requires the top-level `notify` key,
        # when present, to precede all [section] blocks.
        home.file.".codex/config.toml".text = ''
          [mcp_servers.mcp_agent_mail]
          url = "${mcpUrl}"
        '';
      }
      (lib.mkIf pkgs.stdenv.isDarwin {
        # Single long-lived HTTP server both harnesses share. STORAGE_ROOT is
        # left at its default (~/.mcp_agent_mail_git_mailbox_repo); git is put
        # on PATH because the mailbox is a GitPython-managed repo.
        launchd.agents.mcp-agent-mail = {
          enable = true;
          config = {
            ProgramArguments = [
              "${mcp-agent-mail}/bin/mcp-agent-mail"
              "serve-http"
              "--host"
              "127.0.0.1"
              "--port"
              "8765"
            ];
            EnvironmentVariables.PATH = "${pkgs.git}/bin:/usr/bin:/bin";
            KeepAlive = true;
            RunAtLoad = true;
            StandardOutPath = "${config.home.homeDirectory}/Library/Logs/mcp-agent-mail.log";
            StandardErrorPath = "${config.home.homeDirectory}/Library/Logs/mcp-agent-mail.log";
          };
        };
      })
    ];
}
