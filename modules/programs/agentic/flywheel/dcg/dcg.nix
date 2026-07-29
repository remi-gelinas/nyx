{
  flake.modules.homeManager.flywheel =
    { pkgs, lib, ... }:
    let
      sources = import ./_sources.nix { inherit (pkgs) fetchFromGitHub; };

      # Upstream pins release builds to a nightly toolchain purely to dodge a
      # rustix build regression on bare `nightly` (see their rust-toolchain.toml);
      # the crate itself (edition 2024, rust-version 1.95, no `#![feature(...)]`
      # usage) builds clean on nixpkgs stable rustc.
      dcg = pkgs.rustPlatform.buildRustPackage {
        pname = "dcg";
        inherit (sources.dcg) version src;

        cargoHash = "sha256-S++mnJFaNhnRuMxXi7k8ILQ2i2p+nUHWl1e2B8VsDq0=";

        # All pattern packs are compiled into the binary; no build-time
        # downloads. rusqlite (bundled sqlite) and the tree-sitter grammars
        # behind ast-grep-language need a C compiler, already in stdenv; the
        # unified Apple SDK sysroot (Security/CoreFoundation) is already on
        # darwin stdenv's default search path.
        buildInputs = lib.optionals pkgs.stdenv.hostPlatform.isDarwin [
          pkgs.libiconv
        ];

        doCheck = false;

        meta = {
          description = "Blocks destructive shell commands before an AI coding agent executes them";
          homepage = "https://github.com/Dicklesworthstone/destructive_command_guard";
          # Rider-carrying license (see the ADR closed as nyx-o2a): never
          # lib.licenses.mit, always this unfree custom shape.
          license = lib.licenses.unfree // {
            fullName = "MIT License (with OpenAI/Anthropic Rider)";
            url = "https://github.com/Dicklesworthstone/destructive_command_guard/blob/v${sources.dcg.version}/LICENSE";
          };
          mainProgram = "dcg";
        };
      };
    in
    {
      home.packages = [ dcg ];

      # dcg reads the pending Bash command from the PreToolUse JSON on stdin
      # and emits its own permissionDecision JSON; a destructive command comes
      # back as a deny (e.g. ruleId core.git:reset-hard). The harness owns the
      # deny contract — nothing here to configure beyond pointing at the binary.
      programs.claude-code.settings.hooks.PreToolUse = [
        {
          matcher = "Bash|PowerShell";
          hooks = [
            {
              type = "command";
              command = lib.getExe dcg;
            }
          ];
        }
      ];
    };
}
