{
  flake.modules.homeManager.flywheel =
    { config, pkgs, ... }:
    let
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

      agentsTemplate = ./context/AGENTS-template.md;
    in
    {
      home.packages = [ pkgs.master.codex ];

      # br ships its skill under .claude/skills/br/ in the pinned source
      # already, references/ included — pointed at directly rather than
      # copied.
      programs.claude-code.skills = {
        br = "${brSources.br.src}/.claude/skills/br";
        bv = bvSkill;
        ntm = ntmSkill;
      };

      # Mechanizes the per-repo bootstrap from flywheel.md: template the
      # AGENTS.md, initialize the bead board, and install the mail server's
      # advisory pre-commit lease guard. `guard install` takes PROJECT and
      # REPO positionally (verified against the built mcp-agent-mail binary);
      # project_key convention throughout is the absolute repo path, so both
      # get $PWD.
      programs.fish.functions.flywheel-init = ''
        if not test -f AGENTS.md
          cp ${agentsTemplate} AGENTS.md
        end
        if not test -d .beads
          br init
        end
        mcp-agent-mail guard install $PWD $PWD
        echo "Export BR_ACTOR and AGENT_NAME in every agent pane before running br or agent-mail calls."
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

      # Global operating rules for both harnesses. Claude Code renders context
      # into ~/.claude/CLAUDE.md (and reads AGENTS.md natively as of 2.1.211,
      # so no CLAUDE.md->AGENTS.md symlink is needed); Codex reads its global
      # instructions from ~/.codex/AGENTS.md. AGENTS-template.md stays a
      # per-repo template the user copies into each project, not global.
      programs.claude-code.context = builtins.readFile ./context/flywheel.md;
      home.file.".codex/AGENTS.md".text = builtins.readFile ./context/flywheel.md;
      home.file."${config.programs.claude-code.configDir}/CLAUDE.md".force = true;
    };
}
