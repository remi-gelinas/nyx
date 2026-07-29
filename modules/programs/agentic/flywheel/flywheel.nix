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
    in
    {
      home.packages = [ pkgs.master.codex ];

      # The bd allows vanished with the beads module; these are the flywheel
      # tool CLIs agents drive. Concatenates with the claude-code core list.
      programs.claude-code.settings.permissions.allow = map (p: "Bash(${p}:*)") [
        "br"
        "bv"
        "ntm"
        "ubs"
        "dcg"
        "cass"
        "mcp-agent-mail"
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
