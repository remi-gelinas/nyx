{
  flake.modules.homeManager.languages =
    { pkgs, ... }:
    {
      home.packages = [
        pkgs.bun
        pkgs.master.uv
      ];
    };
}
