# Pinned source for br (beads_rust). Underscore prefix keeps this out of
# import-tree; imported directly by br.nix.
{ fetchFromGitHub }:
{
  br =
    let
      version = "0.5.7";
    in
    {
      inherit version;
      src = fetchFromGitHub {
        owner = "Dicklesworthstone";
        repo = "beads_rust";
        tag = "v${version}";
        hash = "sha256-xop9zM674gsxjPV9rlwCDGr8PvFs7N5W6ZCRKpTAGrI=";
      };
      cargoHash = "sha256-Qbz9+tFdFuxaiFVgPV4RQTx0T2JnrKKFEh/APYznNVc=";
    };
}
