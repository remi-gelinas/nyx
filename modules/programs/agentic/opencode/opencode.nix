{ ... }:
{
  flake.modules.homeManager.opencode =
    { config, pkgs, lib, ... }:
    {
      programs.opencode = {
        enable = true;
        package = pkgs.master.opencode;

        settings = {
          # Bare-terminal default; ntm panes pass their model per spawn spec.
          model = "openrouter/anthropic/claude-opus-5.5";
          # nix owns the binary.
          autoupdate = false;

          # {file:...} is opencode's launch-time substitution — the key is
          # read when a session starts and never rendered into the store or
          # the generated config.
          providers.openrouter.settings.apiKey = "{file:${config.home.homeDirectory}/.config/openrouter/key}";

          # Autonomy floor for interactive sessions: dependency installs and
          # local git writes must not stall on approval prompts. Pushes are
          # deliberately absent — the Git context rules govern them. (Swarm
          # panes run --auto and bypass this entirely.) A bare prefix only
          # matches the bare command, so each prefix gets both forms.
          permissions =
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
              rule = resource: {
                action = "shell";
                inherit resource;
                effect = "allow";
              };
            in
            lib.concatMap (p: [
              (rule p)
              (rule "${p} *")
            ]) prefixes;
        };

        skills.dendritic-nix = ./_skills/dendritic-nix;
      };
    };
}
