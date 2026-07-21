{
  flake.modules.homeManager.agent-orchestration =
    { config, lib, ... }:
    let
      globalContext = builtins.concatStringsSep "\n\n" [
        (builtins.readFile ./general.md)
        (builtins.readFile ./orchestration.md)
      ];
    in
    {
      programs.claude-code = {
        context = lib.mkMerge [
          globalContext
          (lib.mkAfter (builtins.readFile ./claude/context.md))
        ];

        agents = {
          researcher = ./claude/researcher.md;
          deep-researcher = ./claude/deep-researcher.md;
          implementer = ./claude/implementer.md;
          integrator = ./claude/integrator.md;
          reviewer = ./claude/reviewer.md;
          deep-reviewer = ./claude/deep-reviewer.md;
          security-reviewer = ./claude/security-reviewer.md;
          cost-auditor = ./claude/cost-auditor.md;
          docs-warden = ./claude/docs-warden.md;
          harness-miner = ./claude/harness-miner.md;
        };

        skills.orchestrating-teams = ./_skills/orchestrating-teams;
      };

      home.file."${config.programs.claude-code.configDir}/CLAUDE.md".force = true;
    };
}
