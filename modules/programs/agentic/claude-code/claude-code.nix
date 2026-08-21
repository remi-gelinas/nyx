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
            # autonomous teams on approval prompts. Pushes are deliberately
            # absent: the Git context rules govern them (non-default
            # branches free, default/protected branches ask).
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
              map (p: "Bash(${p}:*)") prefixes;
          };
          skipAutoPermissionPrompt = true;
          skipWorkflowUsageWarning = true;
          spinnerTipsEnabled = false;
          promptSuggestionEnabled = false;
          awaySummaryEnabled = false;
          # Kills the harness-injected co-author trailer and "Generated with
          # Claude Code" PR footer at the source; the context rule against
          # bylines was losing to the harness's own prompt.
          includeCoAuthoredBy = false;
          # Agent teams are deliberately OFF on the flywheel branch. The
          # methodology is a flat peer swarm — ntm spawns sibling agents that
          # coordinate via agent-mail + file leases; a claude spawning its own
          # teammates creates agents outside ntm's pane map, agent-mail
          # registration, and the lease guard, which can silently trample the
          # swarm's reservations. Removing the enable flag (not setting it to
          # "0", which may be presence-checked) keeps team formation off; the
          # orchestration harness on trunk keeps it enabled. One-shot read-only
          # subagents via the Agent tool remain available but touch no leases.
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
        };
      };

      # The org policy pins new sessions to sonnet regardless of settings.json;
      # force opus-5 at launch unless the caller passes an explicit --model.
      # Subcommands take no --model flag, so pass them through untouched. No
      # --agent injection: the lead role left with the orchestration stack.
      programs.fish.functions.claude = ''
        # In an ntm pane, export the swarm identity before launch so git
        # commits inherit AGENT_NAME for the lease guard (helper ships with
        # the flywheel aspect; no-op elsewhere).
        functions -q flywheel-agent-env; and flywheel-agent-env
        set -l passthrough agents auth auto-mode doctor gateway install mcp plugin plugins project setup-token ultrareview update upgrade
        if test (count $argv) -gt 0; and contains -- $argv[1] $passthrough
          command claude $argv
        else
          set -l extra
          set -l model claude-opus-5
          set -l i (contains -i -- --model $argv); and set model $argv[(math $i + 1)]
          for a in $argv
            string match -qr -- '^--model=(?<m>.+)$' $a; and set model $m
          end
          # Models with verified 1M windows get the [1m] suffix: claude books
          # ~200k for ids it doesn't recognize, and the suffix corrects the
          # context gauge and native auto-compact, stripped before the request
          # leaves. ntm's spec charset can't carry brackets, so it lands here.
          # (Adjacent-string quoting — "$model"'[1m]' — because [1m] inside
          # the same quotes is fish list-index syntax.)
          set -l million moonshotai/kimi-k3 anthropic/claude-opus-5 \
            deepseek/deepseek-v4-flash
          if contains -- $model $million
            set -l suffixed "$model"'[1m]'
            if test -n "$i"
              set argv[(math $i + 1)] $suffixed
            else if string match -qr -- '^--model=' $argv
              set argv (string replace -- "--model=$model" "--model=$suffixed" $argv)
            else
              set -a extra --model $suffixed
            end
          else if not string match -qr -- '^--model(=.*)?$' $argv
            set -a extra --model $model
          end
          # Slash-bearing model ids are OpenRouter slugs; the helper points
          # this process at OpenRouter's Anthropic-native endpoint. Abort on
          # failure rather than launch on the wrong billing.
          if functions -q flywheel-openrouter-env
            flywheel-openrouter-env $model; or return 1
          end
          command claude $extra $argv
        end
      '';

      home.file."${config.programs.claude-code.configDir}/settings.json".force = true;
    };
}
