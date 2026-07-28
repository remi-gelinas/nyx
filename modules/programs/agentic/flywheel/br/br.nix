{
  flake.modules.homeManager.flywheel =
    { pkgs, ... }:
    let
      sources = import ./_sources.nix { inherit (pkgs) fetchFromGitHub; };

      # Built from pinned source. self_update is upstream's default
      # feature (runtime github self-upgrade) — disabled here since Nix
      # owns updates via the pin bump, not the binary.
      br = pkgs.rustPlatform.buildRustPackage {
        pname = "br";
        inherit (sources.br) version src cargoHash;

        buildNoDefaultFeatures = true;

        nativeBuildInputs = [ pkgs.git ];

        doCheck = false;

        meta = {
          mainProgram = "br";
          license = {
            fullName = "MIT License (with OpenAI/Anthropic Rider)";
            free = false;
            redistributable = false;
          };
        };
      };
    in
    {
      home.packages = [ br ];
    };
}
