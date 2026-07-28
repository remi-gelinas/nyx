{
  flake.modules.homeManager.flywheel =
    { pkgs, lib, ... }:
    let
      sources = import ./_sources.nix { inherit (pkgs) fetchFromGitHub; };

      # Built from pinned source; upstream's own flake.nix builds the same
      # way (buildGoModule, vendor/ committed so vendorHash = null).
      bv = pkgs.buildGoModule {
        pname = "bv";
        inherit (sources.bv) version src vendorHash;

        subPackages = [ "cmd/bv" ];

        ldflags = [
          "-s"
          "-w"
          "-X github.com/Dicklesworthstone/beads_viewer/pkg/version.version=v${sources.bv.version}"
        ];

        meta = {
          description = "Terminal UI for the Beads issue tracker with graph-aware triage";
          homepage = "https://github.com/Dicklesworthstone/beads_viewer";
          # Rider restricts use by/for OpenAI and Anthropic; never
          # lib.licenses.mit. See ADR nyx-o2a: risk accepted, rider is read
          # as targeting the AI vendors, not the individual licensee.
          license = {
            fullName = "MIT License with OpenAI/Anthropic Rider";
            shortName = "mit-openai-anthropic-rider";
            free = false;
            redistributable = false;
          };
          mainProgram = "bv";
          platforms = lib.platforms.unix;
        };
      };
    in
    {
      home.packages = [ bv ];
    };
}
