{
  flake.modules.homeManager.flywheel =
    {
      pkgs,
      lib,
      config,
      ...
    }:
    let
      sources = import ./_sources.nix { inherit (pkgs) fetchurl; };
      riderLicense = import ../_rider-license.nix;

      # Both harnesses point at the same local HTTP transport. The service
      # binds 127.0.0.1 only and localhost is exempted from bearer auth via
      # HTTP_ALLOW_LOCALHOST_UNAUTHENTICATED (the Rust server defaults this to
      # false, unlike the Python one), so no bearer is set: a shared secret
      # here would have to be a world-readable store literal for zero security
      # gain over the loopback bind. /mcp/ is the Rust server's default path.
      mcpUrl = "http://127.0.0.1:8765/mcp/";

      # Two independent roots agent-mail resolves, both defaulting to
      # cwd-relative/ambiguous paths that must be pinned so the launchd
      # service, the CLI guard installer, and every agent's CLI call all read
      # the SAME sqlite row + archive. STORAGE_ROOT holds the git-mailbox
      # archive (the guard reads reservation JSON from here); DATABASE_URL is
      # the sqlite the project registry lives in — its default is cwd-relative,
      # which is what scattered stray DBs into repos and split the reservation
      # database. The Rust server reads the same variable names and accepts
      # the legacy sqlite+aiosqlite:// scheme.
      storageRoot = "${config.home.homeDirectory}/.mcp_agent_mail_git_mailbox_repo";
      databaseUrl = "sqlite+aiosqlite:///${storageRoot}/storage.sqlite3";

      # Publishes the flywheel vars into the user's launchd (gui/$UID)
      # domain so EVERY later-launched process inherits them — critically the
      # non-interactive fish panes ntm spawns for workers and the bare
      # subprocess the pre-commit guard runs as, neither of which sources fish
      # interactive config. Without this, agents fell back to a cwd-relative
      # DB (a stray storage.sqlite3 per repo → split-brain reservations that
      # can't see each other, so exclusivity silently fails) and the guard saw
      # no GIT_IDENTITY_ENABLED and self-exited without enforcing. launchctl is
      # at a fixed macOS path; the values match the pins above.
      sessionEnvSetter = pkgs.writeShellScript "flywheel-session-env" ''
        /bin/launchctl setenv STORAGE_ROOT "${storageRoot}"
        /bin/launchctl setenv DATABASE_URL "${databaseUrl}"
        /bin/launchctl setenv GIT_IDENTITY_ENABLED 1
      '';

      # The Rust rewrite of mcp_agent_mail (same author, same tool surface,
      # same storage layout). It replaces the retired Python implementation,
      # whose per-agent session auth locked relaunched agents out of their own
      # identities over a shared HTTP daemon (file_reservation_paths demanded
      # a registration_token only the first session ever saw) and which
      # documented failure modes under real swarm load (git lock contention,
      # SQLite pool exhaustion). The Rust server trusts agent_name on the
      # loopback bind, reads ntm's per-pane identity files, and ships the
      # pre-commit guard and a full robot CLI (`am`) in one static binary.
      #
      # --set-default pins both roots into the binaries themselves: any CLI
      # call resolves the central sqlite + archive no matter how it is
      # launched (non-interactive fish, a bare hook subprocess, an agent
      # shelling out from a repo cwd) — the case shell env alone cannot cover.
      # An explicit env override (the launchd service) still wins.
      mcp-agent-mail = pkgs.stdenvNoCC.mkDerivation {
        pname = "mcp-agent-mail";
        inherit (sources.mcp-agent-mail) version src;

        sourceRoot = ".";
        nativeBuildInputs = [ pkgs.makeWrapper ];

        # The binary dispatches on argv[0]: `am` is the full robot CLI,
        # `mcp-agent-mail` accepts only MCP server commands — so each wrapper
        # must preserve its invocation name via --argv0.
        installPhase = ''
          runHook preInstall
          for name in mcp-agent-mail am; do
            install -Dm755 $name $out/libexec/$name
            makeWrapper $out/libexec/$name $out/bin/$name \
              --argv0 $name \
              --set-default DATABASE_URL "${databaseUrl}" \
              --set-default STORAGE_ROOT "${storageRoot}"
          done
          runHook postInstall
        '';

        meta = {
          description = "Coordinated multi-agent messaging and coordination MCP server (Rust)";
          homepage = "https://github.com/Dicklesworthstone/mcp_agent_mail_rust";
          license = riderLicense // {
            url = "https://github.com/Dicklesworthstone/mcp_agent_mail_rust/blob/v${sources.mcp-agent-mail.version}/LICENSE";
          };
          sourceProvenance = [ lib.sourceTypes.binaryNativeCode ];
          platforms = [ "aarch64-darwin" ];
          mainProgram = "mcp-agent-mail";
        };
      };
    in
    lib.mkMerge [
      {
        home.packages = [ mcp-agent-mail ];

        # Pin both roots globally so the service, the guard installer, and
        # every agent's CLI call agree on one sqlite + archive.
        # GIT_IDENTITY_ENABLED is set alongside in flywheel.nix.
        home.sessionVariables = {
          STORAGE_ROOT = storageRoot;
          DATABASE_URL = databaseUrl;
        };

        # Covers the interactive-fish case (hm-session-vars.sh is POSIX-only and
        # fish never sources it). This reaches a human's own shell and anything
        # they launch from it, but NOT a non-interactive fish — which is exactly
        # how ntm spawns worker panes (`fish -c` gets none of these). The
        # session-wide launchctl agent below is what reaches those; this stays
        # as the interactive-shell path.
        programs.fish.interactiveShellInit = ''
          set -gx STORAGE_ROOT ${storageRoot}
          set -gx DATABASE_URL ${databaseUrl}
          set -gx GIT_IDENTITY_ENABLED 1
        '';

        # Claude Code reaches the running service over the streamable HTTP
        # transport; no auth header since localhost is exempted from bearer
        # auth on the loopback bind.
        programs.claude-code.mcpServers.mcp-agent-mail = {
          type = "http";
          url = mcpUrl;
        };

        # Codex reads MCP servers from ~/.codex/config.toml, but it also
        # WRITES that file to persist per-directory trust — and codex >=0.119
        # hard-crashes when the file is a read-only store symlink (openai/codex
        # #17593). So this is seeded as a codex-owned writable file, not a
        # home.file symlink: install the MCP block on a fresh machine, append
        # it to a pre-existing config that lacks it, rewrite the retired
        # Python endpoint (/api/) to the Rust one (/mcp/) in place, and
        # otherwise leave the file (and codex's own trust writes) untouched.
        # Appending the section at end keeps any top-level keys ahead of it,
        # satisfying codex's notify-before-sections rule.
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
          elif ${pkgs.gnugrep}/bin/grep -q '127.0.0.1:8765/api/' "$cfg"; then
            run ${pkgs.gnused}/bin/sed -i 's|127.0.0.1:8765/api/|127.0.0.1:8765/mcp/|' "$cfg"
          fi
        '';
      }
      (lib.mkIf pkgs.stdenv.isDarwin (
        {
          # Session-wide env publisher. Runs once at login (RunAtLoad, no
          # KeepAlive — it exits immediately after the setenv calls) so a
          # terminal/tmux/ntm started afterward inherits the vars. This is the
          # only path that reaches ntm's non-interactive worker panes and the
          # guard's hook subprocess; the fish exports only cover interactive
          # shells. Start a fresh login shell (or `launchctl kickstart` it)
          # after switching for it to take effect.
          launchd.agents.flywheel-session-env = {
            enable = true;
            config = {
              ProgramArguments = [ "${sessionEnvSetter}" ];
              RunAtLoad = true;
              StandardOutPath = "${config.home.homeDirectory}/Library/Logs/flywheel-session-env.log";
              StandardErrorPath = "${config.home.homeDirectory}/Library/Logs/flywheel-session-env.log";
            };
          };

          # Working dir stays the storage root (belt-and-suspenders for any
          # path agent-mail still resolves cwd-relative), but DATABASE_URL and
          # STORAGE_ROOT are set explicitly so the service reads the same DB the
          # CLI writes to. git is on PATH because the mailbox is a git-managed
          # repo. --no-tui: launchd has no tty and the server otherwise starts
          # its interactive console. HTTP_ALLOW_LOCALHOST_UNAUTHENTICATED
          # restores the Python server's localhost exemption (Rust defaults it
          # to false), matching the tokenless client configs above. Schema
          # creation and legacy-Python DB detection happen at boot; no separate
          # migrate step.
          launchd.agents.mcp-agent-mail = {
            enable = true;
            config = {
              ProgramArguments = [
                "${mcp-agent-mail}/bin/am"
                "serve-http"
                "--host"
                "127.0.0.1"
                "--port"
                "8765"
                "--no-tui"
              ];
              WorkingDirectory = storageRoot;
              EnvironmentVariables = {
                PATH = "${pkgs.git}/bin:/usr/bin:/bin";
                STORAGE_ROOT = storageRoot;
                DATABASE_URL = databaseUrl;
                HTTP_ALLOW_LOCALHOST_UNAUTHENTICATED = "1";
              };
              KeepAlive = true;
              RunAtLoad = true;
              StandardOutPath = "${config.home.homeDirectory}/Library/Logs/mcp-agent-mail.log";
              StandardErrorPath = "${config.home.homeDirectory}/Library/Logs/mcp-agent-mail.log";
            };
          };
        }
      ))
    ];
}
