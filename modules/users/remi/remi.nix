{ self, lib, ... }:
{
  flake.modules.homeManager.remi =
    { pkgs, ... }:
    {
      imports = with self.modules.homeManager; [
        determinate
        zed
        ghostty
        warp
        tmux
        onepassword
        fonts-pragmata-pro
        fish
        zoxide
        remi-git
        agentic
        direnv
        languages
        devops
        floorp
        home-manager
        nord-base
        self.modules.generic.unstable
        self.modules.generic.master
      ];

      home = {
        username = lib.mkDefault "remi";
        homeDirectory = lib.mkDefault (
          if pkgs.stdenv.hostPlatform.isDarwin then "/Users/remi" else "/home/remi"
        );
        stateVersion = "25.11";
      };
    };
}
