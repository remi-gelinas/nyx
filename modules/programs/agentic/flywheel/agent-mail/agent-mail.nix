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

        # Codex reads MCP servers from ~/.codex/config.toml, but it also
        # WRITES that file to persist per-directory trust — and codex >=0.119
        # hard-crashes when the file is a read-only store symlink (openai/codex
        # #17593). So this is seeded as a codex-owned writable file, not a
        # home.file symlink: install the MCP block on a fresh machine, append
        # it to a pre-existing config that lacks it, and otherwise leave the
        # file (and codex's own trust writes) untouched. Appending the section
        # at end keeps any top-level keys ahead of it, satisfying codex's
        # notify-before-sections rule. Changing the block later needs a
        # re-seed: remove the [mcp_servers.mcp_agent_mail] lines and re-switch.
        home.activation.codexConfigSeed = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
          cfg="$HOME/.codex/config.toml"
          snippet=${
            pkgs.writeText "codex-agent-mail.toml" ''
              [mcp_servers.mcp_agent_mail]
              url = "${mcpUrl}"
            ''
          }
          [ -L "$cfg" ] && run rm -- "$cfg"
          run mkdir -p "$HOME/.codex"
          if [ ! -e "$cfg" ]; then
            run install -m600 "$snippet" "$cfg"
          elif ! ${pkgs.gnugrep}/bin/grep -q 'mcp_servers.mcp_agent_mail' "$cfg"; then
            run sh -c 'cat "$1" >> "$2"' _ "$snippet" "$cfg"
          fi
        '';
      }
      (lib.mkIf pkgs.stdenv.isDarwin (
        let
          storageRoot = "${config.home.homeDirectory}/.mcp_agent_mail_git_mailbox_repo";
        in
        {
          # The sqlite path resolves against the process working directory, so
          # the service must run inside its storage root or it dies at startup
          # with "unable to open database file" and KeepAlive loops forever.
          # git is on PATH because the mailbox is a GitPython-managed repo.
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
              WorkingDirectory = storageRoot;
              EnvironmentVariables = {
                PATH = "${pkgs.git}/bin:/usr/bin:/bin";
                STORAGE_ROOT = storageRoot;
              };
              KeepAlive = true;
              RunAtLoad = true;
              StandardOutPath = "${config.home.homeDirectory}/Library/Logs/mcp-agent-mail.log";
              StandardErrorPath = "${config.home.homeDirectory}/Library/Logs/mcp-agent-mail.log";
            };
          };

          # The schema is not created on first serve; without this the service
          # cannot start at all. Idempotent: migrate only when the db is absent.
          home.activation.agentMailMigrate = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
            if [ ! -f "${storageRoot}/storage.sqlite3" ]; then
              run mkdir -p "${storageRoot}"
              run cd "${storageRoot}" && run ${mcp-agent-mail}/bin/mcp-agent-mail migrate
            fi
          '';
        }
      ))
    ];
}
