# Pinned source for ntm (Named Tmux Manager). Underscore prefix keeps this
# out of import-tree; imported directly by ntm.nix.
{ fetchFromGitHub }:
{
  ntm =
    let
      version = "1.30.0";
    in
    {
      inherit version;
      src = fetchFromGitHub {
        owner = "Dicklesworthstone";
        repo = "ntm";
        tag = "v${version}";
        hash = "sha256-ETC2LoFar6FKTnjzTjKZ+7Tlcv2z5QR3mT4zYsTvLHk=";
      };
      # No vendor/ committed upstream; fetched via vendorHash.
      vendorHash = "sha256-Ks/8pCbvDnmAH0rDjAMq1DXH93Jz34Tr0bQfhQ0yBTg=";
    };
}
