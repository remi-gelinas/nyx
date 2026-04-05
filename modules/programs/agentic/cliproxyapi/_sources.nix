# Pinned source for CLIProxyAPI. Underscore prefix keeps this out of
# import-tree; imported directly by cliproxyapi.nix.
{ fetchFromGitHub }:
{
  cliproxyapi = rec {
    version = "7.2.88";
    src = fetchFromGitHub {
      owner = "router-for-me";
      repo = "CLIProxyAPI";
      tag = "v${version}";
      hash = "sha256-r/KeM4s5E/shhy97MOQftJwU1RuoGwYNJYXINQAKxAo=";
    };
    vendorHash = "sha256-xirNOpnPVwe/TqEYkHHLMWREajosaisBazvy8rFEIak=";
  };
}
