# Pinned source for ntm (Named Tmux Manager). Underscore prefix keeps this
# out of import-tree; imported directly by ntm.nix.
{ fetchFromGitHub }:
{
  ntm =
    let
      version = "1.31.0";
    in
    {
      inherit version;
      src = fetchFromGitHub {
        owner = "Dicklesworthstone";
        repo = "ntm";
        tag = "v${version}";
        hash = "sha256-k4Wqa2WYXxDgFtyxr7NOwZRs/EMPkz/exV+flb/FB38=";
      };
      # No vendor/ committed upstream; fetched via vendorHash.
      vendorHash = "sha256-Ks/8pCbvDnmAH0rDjAMq1DXH93Jz34Tr0bQfhQ0yBTg=";
    };
}
