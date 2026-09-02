# Pinned source for beads_viewer (bv). Underscore prefix keeps this out of
# import-tree; imported directly by bv.nix.
{ fetchFromGitHub }:
{
  bv =
    let
      version = "0.22.0";
    in
    {
      inherit version;
      src = fetchFromGitHub {
        owner = "Dicklesworthstone";
        repo = "beads_viewer";
        tag = "v${version}";
        hash = "sha256-a5EMQgwuSwJEVXRsrpUHbbC884pj+tNdFq4A9VpW0k4=";
      };
      # vendor/ is committed upstream; buildGoModule uses it directly.
      vendorHash = null;
    };
}
