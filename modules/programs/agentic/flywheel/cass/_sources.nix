# Pinned source for coding_agent_session_search (cass). Underscore prefix
# keeps this out of import-tree; imported directly by cass.nix.
{ fetchFromGitHub }:
{
  cass = rec {
    version = "0.6.22";
    src = fetchFromGitHub {
      owner = "Dicklesworthstone";
      repo = "coding_agent_session_search";
      tag = "v${version}";
      hash = "sha256-VVrTszc/t++xVCIrPXdDCqkWHGP9UrWVZBuJT2qMvZ4=";
    };
  };
}
