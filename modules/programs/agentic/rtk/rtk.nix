{ self, ... }:
{
  flake.modules.homeManager.rtk =
    { pkgs, ... }:
    {
      imports = with self.modules.homeManager; [ rtk-claude-code ];

      home.packages = [ pkgs.master.rtk ];
    };
}
