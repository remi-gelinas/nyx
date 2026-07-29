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

      # Two independent roots agent-mail resolves, both defaulting to
      # cwd-relative/ambiguous paths that must be pinned so the launchd
      # service, the CLI `guard install`, the headless project-register shim,
      # and every agent's CLI call all read the SAME sqlite row + archive.
      # STORAGE_ROOT holds the git-mailbox archive (the guard reads reservation
      # JSON from here); DATABASE_URL is the sqlite the project registry lives
      # in — its default `./storage.sqlite3` is cwd-relative, which is what
      # scattered stray DBs into repos and made `guard install` read an empty
      # DB and report "Project not found".
      storageRoot = "${config.home.homeDirectory}/.mcp_agent_mail_git_mailbox_repo";
      databaseUrl = "sqlite+aiosqlite:///${storageRoot}/storage.sqlite3";

      # Project registration is MCP-only (no CLI), but `_ensure_project` is an
      # importable coroutine, so flywheel-init can register a repo headlessly
      # before `guard install` (which looks the project up in the DB). Runs
      # against the pinned DATABASE_URL so the row lands where guard install
      # and the service read it.
      registerScript = pkgs.writeText "flywheel-register-project.py" ''
        import asyncio, sys
        from mcp_agent_mail.app import _ensure_project
        asyncio.run(_ensure_project(sys.argv[1]))
      '';

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
          makeWrapper ${ps.python.interpreter} $out/bin/flywheel-register-project \
            --add-flags "${registerScript}" \
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

        # Pin both roots globally so the service, `guard install`, the register
        # shim, and every agent's CLI call agree on one sqlite + archive.
        # GIT_IDENTITY_ENABLED (the guard gate) is set alongside in flywheel.nix.
        home.sessionVariables = {
          STORAGE_ROOT = storageRoot;
          DATABASE_URL = databaseUrl;
        };

        # home.sessionVariables only reaches POSIX shells (hm-session-vars.sh);
        # this host's shell is fish, which never sources it — so without this
        # the register shim/guard install fall back to a cwd-relative DB (stray
        # storage.sqlite3 in the repo) and, worse, the pre-commit hook sees no
        # GIT_IDENTITY_ENABLED at commit time and self-exits without enforcing.
        # `set -gx` exports to fish and every process it launches (agents, and
        # the git commit that triggers the hook).
        programs.fish.interactiveShellInit = ''
          set -gx STORAGE_ROOT ${storageRoot}
          set -gx DATABASE_URL ${databaseUrl}
          set -gx GIT_IDENTITY_ENABLED 1
        '';

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
        {
          # Working dir stays the storage root (belt-and-suspenders for any
          # path agent-mail still resolves cwd-relative), but DATABASE_URL and
          # STORAGE_ROOT are set explicitly so the service reads the same DB the
          # CLI and register shim write to. git is on PATH because the mailbox
          # is a GitPython-managed repo.
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
                DATABASE_URL = databaseUrl;
              };
              KeepAlive = true;
              RunAtLoad = true;
              StandardOutPath = "${config.home.homeDirectory}/Library/Logs/mcp-agent-mail.log";
              StandardErrorPath = "${config.home.homeDirectory}/Library/Logs/mcp-agent-mail.log";
            };
          };

          # The schema is not created on first serve; without this the service
          # cannot start at all. Idempotent: migrate only when the db is absent,
          # against the pinned DATABASE_URL.
          home.activation.agentMailMigrate = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
            if [ ! -f "${storageRoot}/storage.sqlite3" ]; then
              run mkdir -p "${storageRoot}"
              run env DATABASE_URL="${databaseUrl}" STORAGE_ROOT="${storageRoot}" ${mcp-agent-mail}/bin/mcp-agent-mail migrate
            fi
          '';
        }
      ))
    ];
}
