# Pinned source for destructive_command_guard (dcg). Underscore prefix keeps
# this out of import-tree; imported directly by dcg.nix.
{ fetchFromGitHub }:
{
  dcg =
    let
      version = "0.7.3";
    in
    {
      inherit version;
      src = fetchFromGitHub {
        owner = "Dicklesworthstone";
        repo = "destructive_command_guard";
        tag = "v${version}";
        hash = "sha256-0TNTvrXE+x9XU982kkW5vWgWsbnvCHvXzM4MVOgfGPo=";
      };
    };
}
