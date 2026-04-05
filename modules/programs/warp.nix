{
  flake.modules.homeManager.warp =
    { pkgs, ... }:
    {
      home.packages = [ pkgs.master.warp-terminal ];
    };
}
