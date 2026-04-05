{
  flake.modules.homeManager.claude-code-tmux =
    { pkgs, lib, ... }:
    let
      # Teammates title their own panes with the agent type via escape
      # sequences, so every implementer pane reads "implementer". Freeze
      # app titling per pane and stamp the member name from the team
      # config instead. Registration lands a few seconds after the pane
      # is created, so retry briefly.
      retitle = pkgs.writeShellScript "claude-team-retitle" ''
        for _ in $(seq 1 10); do
          for f in "$HOME"/.claude/teams/*/config.json; do
            [ -e "$f" ] || continue
            ${lib.getExe pkgs.jq} -r '.members[] | select((.tmuxPaneId // "") != "") | "\(.tmuxPaneId) \(.name)"' "$f"
          done | while read -r pane name; do
            tmux set -p -t "$pane" allow-set-title off 2>/dev/null
            tmux select-pane -t "$pane" -T "$name" 2>/dev/null
          done
          sleep 1
        done
      '';
    in
    {
      # Re-tile evenly on pane create/destroy, but only in sessions marked
      # @claude_team, so teammate panes stay roughly equal-sized without
      # flattening manual layouts elsewhere.
      programs.tmux.extraConfig = ''
        set-hook -g after-split-window 'if -F "#{@claude_team}" "select-layout tiled; run-shell -b ${retitle}"'
        set-hook -g after-kill-pane 'if -F "#{@claude_team}" "select-layout tiled"'
        set-hook -g pane-exited 'if -F "#{@claude_team}" "select-layout tiled"'
      '';

      # Mark the surrounding tmux session on the first agent dispatch, before
      # any teammate pane is created.
      programs.claude-code.settings.hooks.PreToolUse = [
        {
          matcher = "Agent";
          hooks = [
            {
              type = "command";
              command = ''[ -n "$TMUX" ] && tmux set @claude_team 1; exit 0'';
            }
          ];
        }
      ];
    };
}
