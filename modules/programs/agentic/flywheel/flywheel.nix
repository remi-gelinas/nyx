{
  flake.modules.homeManager.flywheel =
    { config, pkgs, ... }:
    let
      # Same paths agent-mail.nix pins; recomputed here so flywheel-init is
      # self-sufficient and works even from a stale pre-switch shell that never
      # sourced the exports.
      storageRoot = "${config.home.homeDirectory}/.mcp_agent_mail_git_mailbox_repo";
      databaseUrl = "sqlite+aiosqlite:///${storageRoot}/storage.sqlite3";

      # The lease guard reads AGENT_NAME from the commit env, but ntm assigns
      # per-pane identity in its own table and never exports it (confirmed by
      # spawning: pane 1 registered as an agent name, tmux env carried none of
      # it — and tmux session env is shared, so it structurally can't hold a
      # distinct name per pane). This wrapper recovers the identity from ground
      # truth at commit time: TMUX_PANE (set per pane by tmux) looked up in
      # `ntm mapping`'s pane->name table. It fronts the guard's chain-runner so
      # every chained hook inherits AGENT_NAME/BR_ACTOR. No-op outside tmux/ntm
      # (a non-swarm commit then hits the guard's normal AGENT_NAME error).
      identityWrapper = pkgs.writeShellScript "flywheel-precommit-identity" ''
        # flywheel-identity-wrapper
        if [ -z "$AGENT_NAME" ] && [ -n "$TMUX_PANE" ] && command -v ntm >/dev/null 2>&1 && command -v tmux >/dev/null 2>&1; then
          _session=$(tmux display-message -p '#{session_name}' 2>/dev/null)
          if [ -n "$_session" ]; then
            _name=$(ntm mapping --session "$_session" 2>/dev/null | ${pkgs.gawk}/bin/awk -v p="$TMUX_PANE" '$3==p{print $1; exit}')
            if [ -n "$_name" ]; then
              AGENT_NAME="$_name"; export AGENT_NAME
              [ -z "$BR_ACTOR" ] && { BR_ACTOR="$_name"; export BR_ACTOR; }
            fi
          fi
        fi
        exec "$(dirname "$0")/pre-commit.flywheel-inner" "$@"
      '';

      # Harvested from post_compact_reminder's installer (the script it embeds
      # in render_hook_script, default TEMPLATE_DEFAULT message) rather than
      # running the installer: shebang comes from writeShellScript, jq is
      # pinned to the store path. Fires on SessionStart source="compact" and
      # prints the reread-AGENTS.md reminder into the fresh context.
      postCompactReminder = pkgs.writeShellScript "claude-post-compact-reminder" ''
        set -e
        MESSAGE='🚨 IMPORTANT: Context was just compacted. STOP. You MUST:
        1. Read AGENTS.md NOW
        2. Confirm by briefly stating what key rules/conventions you found

        Do not proceed with any task until you have read the file and confirmed what you learned.'
        INPUT=$(cat)
        SOURCE=$(printf '%s' "$INPUT" | ${pkgs.jq}/bin/jq -r '.source // empty' 2>/dev/null || true)
        if [ "$SOURCE" = "compact" ]; then
          printf '%s\n' "$MESSAGE"
        fi
        exit 0
      '';

      # Codex is plain nixpkgs (MIT-clean vendor tooling), pulled from
      # nixpkgs-master for the current release. ntm can then spawn both claude
      # and codex panes. Auth is a one-time interactive `codex login` by the
      # user; this only delivers the binary.

      brSources = import ./br/_sources.nix { inherit (pkgs) fetchFromGitHub; };
      bvSources = import ./bv/_sources.nix { inherit (pkgs) fetchFromGitHub; };
      ntmSources = import ./ntm/_sources.nix { inherit (pkgs) fetchFromGitHub; };

      # bv and ntm ship SKILL.md at their repo root rather than under
      # .claude/skills/, so each gets a minimal one-file skill dir instead of
      # pointing the skill at the whole repo checkout.
      ntmSkill = pkgs.runCommand "ntm-skill" { } ''
        mkdir -p $out
        cp ${ntmSources.ntm.src}/SKILL.md $out/SKILL.md
      '';

      # Same treatment for bv, plus a text fix: bv's own "Agent Workflow
      # Pattern" (not the section below it that's explicitly labeled legacy)
      # tells the agent to run `bd claim`/`bd close`, but `bd` is the old Go
      # binary — br is current. Swapped for br's actual equivalents, keyed on
      # the actor var flywheel-init tells every pane to export.
      bvSkill = pkgs.runCommand "bv-skill" { } ''
        mkdir -p $out
        sed \
          -e 's/^bd claim "\$NEXT_TASK"$/br update --actor "$BR_ACTOR" "$NEXT_TASK" --status in_progress --claim/' \
          -e 's/^bd close "\$NEXT_TASK"$/br close --actor "$BR_ACTOR" "$NEXT_TASK" --reason "Completed"/' \
          ${bvSources.bv.src}/SKILL.md > $out/SKILL.md
      '';

      # Global operator context = the methodology rules plus the repo-agnostic
      # tool reference, delivered to both harnesses' user-level instruction
      # files. Nothing here is committed into a project.
      globalContext = builtins.readFile ./context/flywheel.md + "\n" + builtins.readFile ./context/tool-reference.md;
    in
    {
      home.packages = [ pkgs.master.codex ];

      # The guard gate. `settings.worktrees_enabled` is (WORKTREES_ENABLED OR
      # GIT_IDENTITY_ENABLED); either satisfies both `guard install` and the
      # runtime hook's commit-time re-check. The flywheel is single-branch with
      # per-agent git identity, so the identity alias is the honest name, and
      # it is a constant — global session env, not a per-pane export like
      # BR_ACTOR/AGENT_NAME. (STORAGE_ROOT and DATABASE_URL are set alongside
      # in agent-mail.nix.) PROJECT_IDENTITY_MODE is left at its default `dir`
      # so the project slug stays slugify(path) and the register shim, the
      # guard, and the server all compute the same slug.
      home.sessionVariables.GIT_IDENTITY_ENABLED = "1";

      # br ships its skill under .claude/skills/br/ in the pinned source
      # already, references/ included — pointed at directly rather than
      # copied.
      programs.claude-code.skills = {
        br = "${brSources.br.src}/.claude/skills/br";
        bv = bvSkill;
        ntm = ntmSkill;
      };

      # Per-repo mechanical bootstrap only — no committed context. The tool
      # blurbs and methodology live in global operator context (see below), so
      # a solo adopter never writes a flywheel-flavored AGENTS.md into a shared
      # repo. Steps, in order: refuse a repo that already has a bd (Dolt) board
      # (br and bd both claim `.beads/`); init the br board; register the repo
      # as an agent-mail project (MCP-only op, done headlessly via the register
      # shim, so the next step's DB lookup succeeds); install the advisory
      # pre-commit lease guard. All local state — `.beads/` is gitignorable,
      # registration lands in the shared DATABASE_URL, the guard in
      # `.git/hooks/`. `guard install` takes PROJECT and REPO positionally
      # (both the absolute repo path).
      programs.fish.functions.flywheel-init = ''
        set -lx STORAGE_ROOT ${storageRoot}
        set -lx DATABASE_URL ${databaseUrl}
        set -lx GIT_IDENTITY_ENABLED 1
        if test -d .beads/embeddeddolt
          echo "This repo has a bd (Dolt) board at .beads/; br would collide. Migrate it (bd export | br import) or run the flywheel on a repo without one. Aborting."
          return 1
        end
        if not test -d .beads
          br init
        end
        flywheel-register-project $PWD
        mcp-agent-mail guard install $PWD $PWD
        # Front the guard's chain-runner with the identity wrapper so
        # AGENT_NAME auto-derives from the tmux pane. Re-wrap whenever the
        # current hook isn't ours (guard install regenerates it on re-runs).
        set -l hook .git/hooks/pre-commit
        if test -f $hook; and not grep -q flywheel-identity-wrapper $hook
          mv $hook $hook.flywheel-inner
          cp ${identityWrapper} $hook
          chmod +x $hook
        end
        echo "Board, agent-mail project, and lease guard ready. Agent identity auto-derives from the tmux pane; no per-pane AGENT_NAME export needed."
      '';

      # The bd allows vanished with the beads module; these are the flywheel
      # tool CLIs agents drive. Concatenates with the claude-code core list.
      # ntm and cass are kept broad deliberately (single-user machine,
      # experiment friction outweighs the narrower-allowlist benefit) per
      # review. agent-mail is MCP-only here: agents drive it through the
      # MCP server, and the CLI stays reachable via normal prompting without
      # a standing Bash allow.
      programs.claude-code.settings.permissions.allow = map (p: "Bash(${p}:*)") [
        "br"
        "bv"
        "ntm"
        "ubs"
        "dcg"
        "cass"
      ];

      programs.claude-code.settings.hooks.SessionStart = [
        {
          matcher = "compact";
          hooks = [
            {
              type = "command";
              command = "${postCompactReminder}";
            }
          ];
        }
      ];

      programs.claude-code.settings.skipDangerousModePermissionPrompt = true;

      # Global operating rules + tool reference for both harnesses. Claude Code
      # renders context into ~/.claude/CLAUDE.md; Codex reads ~/.codex/AGENTS.md.
      # Both are user-level and machine-local — a solo adopter's flywheel
      # knowledge reaches their own agents on every repo without committing
      # anything, so shared repos and their other contributors are untouched.
      programs.claude-code.context = globalContext;
      home.file.".codex/AGENTS.md".text = globalContext;
      home.file."${config.programs.claude-code.configDir}/CLAUDE.md".force = true;
    };
}
