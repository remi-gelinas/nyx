# Pinned source for mcp_agent_mail_rust. Underscore prefix keeps this out of
# import-tree; imported directly by agent-mail.nix.
#
# This is the upstream release BINARY, not a source build: the Cargo workspace
# depends on sibling path-only crates (../frankensearch, ../fastmcp_rust,
# ../frankentui, ../beads_rust, ...) with no registry fallback, on a pinned
# nightly — building from source means vendoring the author's entire crate
# universe at exact matching revisions. The release asset is checksummed
# (verified against the published .sha256) and Sigstore-signed upstream.
{ fetchurl }:
{
  mcp-agent-mail =
    let
      version = "0.3.24";
    in
    {
      inherit version;
      src = fetchurl {
        url = "https://github.com/Dicklesworthstone/mcp_agent_mail_rust/releases/download/v${version}/mcp-agent-mail-aarch64-apple-darwin.tar.gz";
        hash = "sha256-EqwzL4SM/mBXLPPOLkJpADQf9dWlMb3Wpc7amOqD+ro=";
      };
    };
}
