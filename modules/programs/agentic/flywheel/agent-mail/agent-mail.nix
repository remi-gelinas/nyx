{
  flake.modules.homeManager.flywheel =
    { pkgs, ... }:
    let
      sources = import ./_sources.nix { inherit (pkgs) fetchFromGitHub; };
      ps = pkgs.python3Packages;

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
          # Rider-carrying license: the MIT grant excludes the AI vendors and
          # their agents, so this is never lib.licenses.mit.
          license = {
            fullName = "MIT License (with OpenAI/Anthropic Rider)";
            url = "https://github.com/Dicklesworthstone/mcp_agent_mail/blob/v${sources.mcp-agent-mail.version}/LICENSE";
            free = false;
            redistributable = false;
          };
          mainProgram = "mcp-agent-mail";
        };
      };
    in
    {
      home.packages = [ mcp-agent-mail ];
    };
}
