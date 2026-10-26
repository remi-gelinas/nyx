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

      # Injected into opencode's global context so agents reach for the graph
      # before grep. opencode has no stdout-injection session hook, so this
      # rides the context file rather than a SessionStart hook; the live
      # Grep/Glob augmentation is the opencode plugin's job (hook-augment).
      discoveryProtocol = ''
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
      '';
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

      # Local (stdio) MCP server: spawned per session by opencode, no daemon
      # needed. The per-repo SQLite index lives in ~/.cache and is shared
      # across sessions; incremental git-sync runs inside the server.
      programs.opencode = {
        settings = {
          mcp.servers.codebase-memory = {
            type = "local";
            command = [ "${codebase-memory-mcp}/bin/codebase-memory-mcp" ];
          };
          # manage_adr is a single-document store, not a numbered registry.
          # Sessions that "recorded" ADRs through it recorded nothing usable.
          # Decisions live on the br board. Deny structurally — prose
          # prohibitions drift. tool.use lives in the top-level policies list
          # (allow/deny), not the permissions ruleset (whose actions are
          # per-tool like shell/edit and whose unknown actions match nothing).
          policies = [
            {
              action = "tool.use";
              resource = "codebase-memory_manage_adr*";
              effect = "deny";
            }
          ];
          # Grep/Glob search augmenter (runs hook-augment) plus its liveness
          # sentinel.
          plugins = [ "${./_opencode-plugin}" ];
        };
        skills.codebase-memory = ./_skills/codebase-memory;
        context = discoveryProtocol;
      };
    };
}
