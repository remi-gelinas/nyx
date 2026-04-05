# Pinned sources for Claude Code plugins. Underscore prefix keeps this out
# of import-tree; imported directly by claude-code.nix.
{ fetchFromGitHub }:
{
  # Ships skills, commands, rules, and Cloudflare's official remote MCP
  # servers via the plugin's .mcp.json
  cloudflare-skills = fetchFromGitHub {
    owner = "cloudflare";
    repo = "skills";
    rev = "12520fd63a1e958be217a93f48ce1f04bc9055f3";
    hash = "sha256-dkKTLFcAiQ86dgkD58VwS0Y4986hBC6XMOfpmfQpc5Y=";
  };

  ponytail = fetchFromGitHub {
    owner = "DietrichGebert";
    repo = "ponytail";
    tag = "v4.8.4";
    hash = "sha256-1A9GkjCuiqwd6Wxl18CZUGYekxrbeTLVDapNUua8ihg=";
  };

  pulumi-agent-skills = fetchFromGitHub {
    owner = "pulumi";
    repo = "agent-skills";
    rev = "b6b942fc6e34517e2bbc52d6db04ca529baf3ad4";
    hash = "sha256-QCFgqrTRhMk9Ij3vkcvVP76ajuTC2So29Y+lt1MbwK0=";
  };
}
