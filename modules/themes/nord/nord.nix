{ self, ... }:
{
  flake.modules.homeManager.nord-base = {
    imports = with self.modules.homeManager; [
      nord-ghostty
      nord-zed
      nord-claude-code
    ];
  };
}
