{
  flake.modules.homeManager.flywheel =
    { pkgs, ... }:
    let
      sources = import ./_sources.nix { inherit (pkgs) fetchFromGitHub; };

      # ubs is a pure-bash meta-runner: a single ~3.7k-line dispatcher script
      # plus bundled per-language modules/*.sh, no compiled binary. It
      # detects languages, shells out to ripgrep/ast-grep/jq/python3 for the
      # actual regex+AST checks, stages the scan target via rsync, and
      # merges results through jq. It also tries to lazily curl its own
      # modules and an ast-grep binary from GitHub releases at runtime, but
      # only when neither is found on PATH or bundled next to the script —
      # both are satisfied here (ast-grep on the wrapped PATH, modules/
      # installed alongside the script), so the network path never fires.
      ubs = pkgs.stdenv.mkDerivation {
        pname = "ubs";
        inherit (sources.ubs) version src;

        nativeBuildInputs = [ pkgs.makeWrapper ];

        dontBuild = true;

        # modules/ must live next to the real script (ubs resolves its own
        # dir via BASH_SOURCE + realpath and looks for ./modules/<lang>.sh
        # there before falling back to a downloaded cache).
        installPhase = ''
          mkdir -p $out/share/ubs
          cp -r modules $out/share/ubs/modules
          install -Dm755 ubs $out/share/ubs/ubs
          mkdir -p $out/bin
          ln -s $out/share/ubs/ubs $out/bin/ubs
        '';

        # Every tool the core dispatcher shells out to unconditionally:
        # ast-grep/rg/jq/python3 for scanning, rsync to stage the scan
        # target, git for --diff/--staged, coreutils/bash for the rest.
        postFixup = ''
          wrapProgram $out/bin/ubs --prefix PATH : ${
            pkgs.lib.makeBinPath [
              pkgs.bash
              pkgs.coreutils
              pkgs.ripgrep
              pkgs.ast-grep
              pkgs.jq
              pkgs.python3
              pkgs.git
              pkgs.rsync
            ]
          }
        '';

        meta = {
          description = "Multi-language bug scanner: bash dispatcher over ripgrep/ast-grep/jq/python3 per-language checks";
          homepage = "https://github.com/Dicklesworthstone/ultimate_bug_scanner";
          mainProgram = "ubs";
          # MIT with an added OpenAI/Anthropic use rider; risk accepted per
          # ADR nyx-o2a, carried as an unfree custom license, never mit.
          license = {
            fullName = "MIT License (with OpenAI/Anthropic Rider)";
            shortName = "mit-openai-anthropic-rider";
            url = "https://github.com/Dicklesworthstone/ultimate_bug_scanner/blob/v${sources.ubs.version}/LICENSE";
            free = false;
          };
        };
      };
    in
    {
      home.packages = [ ubs ];
    };
}
