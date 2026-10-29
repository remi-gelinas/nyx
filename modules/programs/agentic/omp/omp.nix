{ inputs, ... }:
{
  flake.modules.homeManager.omp =
    { config, lib, ... }:
    let
      cfg = config.programs.omp;
    in
    {
      imports = [
        inputs.omp.homeManagerModules.default
      ];

      options.programs.omp = {
        context = lib.mkOption {
          type = lib.types.lines;
          default = "";
          description = "Global instructions shared by main sessions and read-only helpers.";
        };
        skills = lib.mkOption {
          type = lib.types.attrsOf lib.types.path;
          default = { };
          description = "Skill directories installed in OMP's native user directory.";
        };
        mcpServers = lib.mkOption {
          type = lib.types.attrsOf lib.types.anything;
          default = { };
          description = "Native OMP MCP server definitions.";
        };
      };

      config = {
        programs.omp = {
          enable = true;
          settings = {
            modelRoles.default = "openrouter/anthropic/claude-opus-5.5";
            startup.checkUpdate = false;
            # Nix owns onboarding choices. `omp setup` is interactive and
            # must not run during activation or intercept NTM's first prompt.
            startup.setupWizard = false;
            # Throughput sorting is injected per model, without Nitro's
            # additional priority endpoint eligibility.
            providers.openrouterVariant = "default";
            extensions = [ "${./_extensions/openrouter-routing}" ];
            # Native turn-scoped assertions, not the timed OpenCode plugin.
            power.sleepPrevention = "system";

            # Eval subprocesses bypass Bash's DCG interception. Deny even if
            # a project or environment setting re-enables either backend.
            eval = {
              js = false;
              py = false;
              autoProvision = false;
            };
            tools = {
              approvalMode = "write";
              approval.eval = "deny";
            };
            bash.patterns =
              lib.concatMap
                (
                  prefix:
                  map
                    (match: {
                      inherit match;
                      approval = "allow";
                    })
                    [
                      prefix
                      "${prefix} *"
                    ]
                )
                [
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

            # OMP drops context files named AGENTS.md in task subagents.
            contextFiles.extra = [ "NYX.md" ];
            task.isolation.enabled = false;
          };
          skills.dendritic-nix = ../opencode/_skills/dendritic-nix;
        };

        home.file = lib.mkMerge [
          {
            ".omp/agent/NYX.md".text = cfg.context;
            ".omp/agent/mcp.json".text = builtins.toJSON { mcpServers = cfg.mcpServers; };
            # Only the command is stored; the key is resolved when requested.
            ".omp/agent/models.yml".text = builtins.toJSON {
              providers.openrouter.apiKey = "!cat ${lib.escapeShellArg "${config.home.homeDirectory}/.config/openrouter/key"}";
            };
          }
          (lib.mapAttrs' (
            name: source: lib.nameValuePair ".omp/agent/skills/${name}" { inherit source; }
          ) cfg.skills)
        ];
      };
    };
}
