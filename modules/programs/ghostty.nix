{
  flake.modules.homeManager.ghostty =
    { pkgs, ... }:
    {
      programs.ghostty = {
        enable = true;
        package = pkgs.ghostty-bin;

        settings = {
          font-size = 19;
          window-vsync = false;
          window-decoration = false;
        };
      };
    };
}
