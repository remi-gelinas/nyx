{ inputs, ... }:
{
  imports = [
    inputs.git-hooks-nix.flakeModule
  ];

  systems = [
    "aarch64-darwin"
  ];

  perSystem =
    {
      config,
      lib,
      pkgs,
      ...
    }:
    {
      pre-commit.settings = {
        package = pkgs.prek;
        hooks.nixfmt.enable = true;
      };

      devShells.default = config.pre-commit.devShell;

      formatter = pkgs.writeShellApplication {
        name = "pre-commit-run";
        runtimeInputs = [ config.pre-commit.settings.package ];
        text = ''
          ${lib.getExe config.pre-commit.settings.package} run \
            --all-files \
            -c ${config.pre-commit.settings.configFile}
        '';
      };
    };
}
