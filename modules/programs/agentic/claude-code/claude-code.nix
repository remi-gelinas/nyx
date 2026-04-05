{ self, ... }:
{
  flake.modules.homeManager.claude-code =
    { config, pkgs, ... }:
    let
      sources = import ./_sources.nix { inherit (pkgs) fetchFromGitHub; };
    in
    {
      imports = with self.modules.homeManager; [
        claude-code-zed
        claude-code-tmux
        claude-code-cost-ledger
      ];

      programs.claude-code = {
        enable = true;
        package = pkgs.master.claude-code;

        plugins = [
          sources.cloudflare-skills
          "${sources.pulumi-agent-skills}/authoring"
        ];

        settings = {
          model = "claude-fable-5[1m]";
          effortLevel = "high";
          tui = "fullscreen";
          permissions = {
            defaultMode = "auto";
            # Dependency installs and local git writes must not stall
            # autonomous teams on approval prompts. rtk's PreToolUse hook
            # rewrites commands before permission evaluation, so each rule
            # needs its rtk-prefixed twin. Pushes are deliberately absent:
            # the Git context rules govern them (non-default branches free,
            # default/protected branches ask).
            allow =
              let
                prefixes = [
                  "npm install"
                  "npm ci"
                  "npm uninstall"
                  "npm update"
                  "pnpm install"
                  "pnpm add"
                  "pnpm remove"
                  "pnpm update"
                  "yarn install"
                  "yarn add"
                  "bun install"
                  "bun add"
                  "git add"
                  "git commit"
                  "git branch"
                  "git checkout"
                  "git switch"
                  "git merge"
                  "git rebase"
                  "git stash"
                  "git worktree"
                  "git restore"
                ];
              in
              map (p: "Bash(${p}:*)") (prefixes ++ map (p: "rtk ${p}") prefixes);
          };
          skipAutoPermissionPrompt = true;
          skipWorkflowUsageWarning = true;
          # Teammates spawn as tmux split panes when the session runs inside
          # tmux; falls back to in-process otherwise.
          teammateMode = "auto";
          env.CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS = "1";
        };

        mcpServers.github = {
          type = "http";
          url = "https://api.githubcopilot.com/mcp/";
          # GitHub's remote MCP server doesn't support Claude Code's OAuth
          # flow; the PAT is supplied via the environment at launch.
          headers.Authorization = "Bearer \${GITHUB_MCP_TOKEN}";
        };

        skills = {
          dendritic-nix = ./_skills/dendritic-nix;
          ponytail = "${sources.ponytail}/skills/ponytail";
          ponytail-audit = "${sources.ponytail}/skills/ponytail-audit";
          ponytail-debt = "${sources.ponytail}/skills/ponytail-debt";
          ponytail-gain = "${sources.ponytail}/skills/ponytail-gain";
          ponytail-help = "${sources.ponytail}/skills/ponytail-help";
          ponytail-review = "${sources.ponytail}/skills/ponytail-review";
        };
      };

      home.file."${config.programs.claude-code.configDir}/settings.json".force = true;
    };
}
