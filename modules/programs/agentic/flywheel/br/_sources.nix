# Pinned source for br (beads_rust). Underscore prefix keeps this out of
# import-tree; imported directly by br.nix.
{ fetchFromGitHub }:
{
  br =
    let
      version = "0.2.19";
    in
    {
      inherit version;
      src = fetchFromGitHub {
        owner = "Dicklesworthstone";
        repo = "beads_rust";
        tag = "v${version}";
        hash = "sha256-DsXAjFac20UpKuA8kp7Zj90rx6leM5tr6ZeMb+RvsWM=";
      };
      cargoHash = "sha256-9lZgWwSi0v855ihjX9M4RgjSd9jEU8wsjo6jDXnxhUY=";
    };
}
