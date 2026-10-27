{ inputs, self, ... }:
{
  perSystem =
    { pkgs, lib, ... }:
    let
      home = inputs.home-manager.lib.homeManagerConfiguration {
        inherit pkgs;
        modules = [ self.modules.homeManager.remi ];
      };
      cfg = home.config;
      settings = cfg.programs.omp.settings;
    in
    {
      checks.omp-extensions = pkgs.runCommand "omp-extensions" { nativeBuildInputs = [ pkgs.bun ]; } ''
        cp -r ${../flywheel/_omp-extension} flywheel
        cp -r ${../codebase-memory/_omp-extension} codebase-memory
        bun test flywheel/index.test.ts codebase-memory/index.test.ts
        touch $out
      '';

      checks.omp-config =
        assert cfg.programs.opencode.enable && cfg.programs.omp.enable;
        assert settings.modelRoles.default == cfg.programs.opencode.settings.model;
        assert !settings.startup.setupWizard;
        assert settings.tools.approval.eval == "deny";
        assert !settings.eval.js && !settings.eval.py && !settings.eval.autoProvision;
        assert settings.tools.approval.mcp__codebase_memory_manage_adr == "deny";
        assert
          map (rule: rule.match) settings.bash.patterns
          == map (rule: rule.resource) cfg.programs.opencode.settings.permissions;
        assert !settings.task.isolation.enabled;
        assert settings.power.sleepPrevention == "system";
        assert settings.theme.dark == "dark-nord";
        assert settings.contextFiles.extra == [ "NYX.md" ];
        assert
          builtins.attrNames cfg.programs.omp.skills == builtins.attrNames cfg.programs.opencode.skills;
        assert builtins.length settings.extensions == 2;
        assert cfg.programs.omp.mcpServers.codebase-memory.type == "stdio";
        assert
          cfg.programs.omp.mcpServers.mcp-agent-mail.url
          == cfg.programs.opencode.settings.mcp.servers.mcp-agent-mail.url;
        assert cfg.home.file.".omp/agent/NYX.md".text == cfg.programs.omp.context;
        assert lib.hasInfix "CRITICAL - Code Discovery Protocol" cfg.programs.omp.context;
        assert lib.hasInfix "Flywheel Operating Rules" cfg.programs.omp.context;
        pkgs.runCommand "omp-config" { nativeBuildInputs = [ pkgs.fish ]; } ''
          mkdir bin
          cat > bin/ntm <<'EOF'
          #!${pkgs.runtimeShell}
          printf 'BlueLake omp %%1\n'
          EOF
          cat > bin/tmux <<'EOF'
          #!${pkgs.runtimeShell}
          printf 'test-session\n'
          EOF
          cat > bin/omp <<'EOF'
          #!${pkgs.runtimeShell}
          printf '%s\n' "$AGENT_NAME" "$BR_ACTOR" "$@"
          EOF
          chmod +x bin/*
          env -u BR_ACTOR TMUX_PANE=%1 PATH="$PWD/bin:$PATH" fish --no-config ${pkgs.writeText "omp.fish" ''
            function flywheel-agent-env
              ${cfg.programs.fish.functions.flywheel-agent-env}
            end
            function omp
              ${cfg.programs.fish.functions.omp}
            end
            omp --model 'openrouter/vendor/a model' --thinking high
          ''} > actual
          printf '%s\n' BlueLake BlueLake --model 'openrouter/vendor/a model' --thinking high > expected
          cmp expected actual
          grep -F 'command = "omp --yolo' ${cfg.xdg.configFile."ntm/agents/omp.toml".source}
          touch $out
        '';
    };
}
