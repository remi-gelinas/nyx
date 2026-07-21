# Pinned source for codebase-memory-mcp. Underscore prefix keeps this out
# of import-tree; imported directly by codebase-memory.nix.
{ fetchFromGitHub }:
{
  codebase-memory-mcp = rec {
    version = "0.9.0";
    src = fetchFromGitHub {
      owner = "DeusData";
      repo = "codebase-memory-mcp";
      tag = "v${version}";
      hash = "sha256-4P7PVz6vLbokrrKv1QzsWJ3SNULpwyufcXmloHJUVqQ=";
    };
  };
}
