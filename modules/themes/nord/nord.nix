{ self, ... }:
{
  flake.modules.homeManager.nord-base = {
    imports = with self.modules.homeManager; [
      nord-ghostty
      nord-opencode
      nord-omp
    ];
  };
}
