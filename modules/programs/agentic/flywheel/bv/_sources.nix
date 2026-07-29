# Pinned source for beads_viewer (bv). Underscore prefix keeps this out of
# import-tree; imported directly by bv.nix.
{ fetchFromGitHub }:
{
  bv =
    let
      version = "0.18.0";
    in
    {
      inherit version;
      src = fetchFromGitHub {
        owner = "Dicklesworthstone";
        repo = "beads_viewer";
        tag = "v${version}";
        hash = "sha256-jVqC3UtvshTngKFOL3/F+NpBQ8qdVs5GgBXL0lqE2lE=";
      };
      # vendor/ is committed upstream; buildGoModule uses it directly.
      vendorHash = null;
    };
}
