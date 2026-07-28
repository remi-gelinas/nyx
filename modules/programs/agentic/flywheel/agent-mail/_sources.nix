# Pinned source for mcp_agent_mail. Underscore prefix keeps this out of
# import-tree; imported directly by agent-mail.nix.
{ fetchFromGitHub }:
{
  mcp-agent-mail = rec {
    version = "0.3.4";
    src = fetchFromGitHub {
      owner = "Dicklesworthstone";
      repo = "mcp_agent_mail";
      tag = "v${version}";
      hash = "sha256-0pbZG3q64GZDsenEju5BLOhNaZD2gQuQ0aRe7v1T17c=";
    };
  };
}
