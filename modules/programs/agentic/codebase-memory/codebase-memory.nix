{
  flake.modules.homeManager.codebase-memory =
    {
      pkgs,
      lib,
      ...
    }:
    let
      sources = import ./_sources.nix { inherit (pkgs) fetchFromGitHub; };

      # Built from pinned source, mirroring upstream's own flake derivation
      # (make -f Makefile.cbm; grammars and embedding model are vendored in
      # the repo, so the build is fully offline).
      codebase-memory-mcp = pkgs.stdenv.mkDerivation {
        pname = "codebase-memory-mcp";
        inherit (sources.codebase-memory-mcp) version src;

        nativeBuildInputs = [ pkgs.gnumake ];
        buildInputs = [ pkgs.zlib ];

        buildPhase = ''
          make -j$NIX_BUILD_CORES -f Makefile.cbm cbm
        '';

        installPhase = ''
          install -Dm755 build/c/codebase-memory-mcp $out/bin/codebase-memory-mcp
        '';

        meta.mainProgram = "codebase-memory-mcp";
      };

      # Hooks harvested from the upstream installer (its imperative install
      # is replaced by this module; re-harvest on version bumps). The
      # augmenter never blocks: it only adds graph context to searches and
      # exits 0 silently on any failure. v0.9.0 handles Grep/Glob only
      # (hook_augment.c); upstream's newer "post-Read coverage" hook should
      # be harvested and registered on PostToolUse/Read at the next bump.
      searchAugmenter = pkgs.writeShellScript "cbm-search-augmenter" ''
        ${codebase-memory-mcp}/bin/codebase-memory-mcp hook-augment 2>/dev/null
        exit 0
      '';

      sessionReminder = pkgs.writeShellScript "cbm-session-reminder" ''
        cat << 'REMINDER'
        CRITICAL - Code Discovery Protocol:
        1. ALWAYS use codebase-memory-mcp tools FIRST for ANY code exploration:
           - search_graph(name_pattern/label/qn_pattern) to find functions/classes/routes
           - trace_path(function_name, mode=calls|data_flow|cross_service) for call chains
           - get_code_snippet(qualified_name) for exact symbol source (precise ranges)
           - query_graph(query) for complex Cypher patterns
           - get_architecture(aspects) for project structure
           - search_code(pattern) for text search (graph-augmented grep)
        2. Use Grep/Glob/Read freely for text, configs, non-code files, and
           always Read a file before editing it.
        3. If a project is not indexed yet, run index_repository FIRST.
        REMINDER
      '';

      subagentReminder = pkgs.writeShellScript "cbm-subagent-reminder" ''
        printf '%s\n' '{"hookSpecificOutput":{"hookEventName":"SubagentStart","additionalContext":"Code discovery: prefer codebase-memory-mcp tools (search_graph, trace_path, get_code_snippet, query_graph, get_architecture, search_code) over grep/file-read for navigating code. Use Grep/Glob/Read for text, configs, and non-code files."}}'
      '';

      hookOf = command: [ { hooks = [ { type = "command"; inherit command; } ]; } ];
    in
    {
      home.packages = [ codebase-memory-mcp ];

      # auto_index defaults to false, which leaves the graph empty until an
      # agent volunteers to index — the augmenter hook is inert against an
      # empty graph, so nothing ever nudges them. Indexing on session start
      # makes the bootstrap deterministic. The setting lives in the server's
      # own sqlite config, hence an idempotent activation step rather than a
      # managed file.
      home.activation.cbmAutoIndex = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
        run ${codebase-memory-mcp}/bin/codebase-memory-mcp config set auto_index true
      '';

      # stdio MCP server: spawned per session by Claude Code, no daemon
      # needed. The per-repo SQLite index lives in ~/.cache and is shared
      # across sessions; incremental git-sync runs inside the server.
      programs.claude-code = {
        mcpServers.codebase-memory = {
          type = "stdio";
          command = "${codebase-memory-mcp}/bin/codebase-memory-mcp";
        };

        # manage_adr is a single-document store, not a numbered registry.
        # Sessions that "recorded" ADRs through it recorded nothing usable.
        # Decisions live on the br board. Deny the tool structurally —
        # prose prohibitions drift.
        settings.permissions.deny = [
          "mcp__plugin_claude-code-home-manager_codebase-memory__manage_adr"
        ];

        skills.codebase-memory = ./_skills/codebase-memory;

        settings.hooks = {
          PreToolUse = [
            {
              matcher = "Grep|Glob";
              hooks = [
                {
                  type = "command";
                  command = "${searchAugmenter}";
                }
              ];
            }
          ];
          SessionStart = hookOf "${sessionReminder}";
          SubagentStart = hookOf "${subagentReminder}";
        };
      };
    };
}
