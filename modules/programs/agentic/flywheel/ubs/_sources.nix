# Pinned source for ultimate_bug_scanner (ubs). Underscore prefix keeps this
# out of import-tree; imported directly by ubs.nix.
{ fetchFromGitHub }:
{
  ubs = rec {
    version = "5.3.7";
    src = fetchFromGitHub {
      owner = "Dicklesworthstone";
      repo = "ultimate_bug_scanner";
      tag = "v${version}";
      hash = "sha256-63jYXSJXnLWyxq2h0aFZM7SVkb8C/yOsft6vKO9NUAU=";
    };
  };
}
