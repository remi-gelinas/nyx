{ lib, ... }:
{
  flake.modules.homeManager.remi-git =
    { pkgs, ... }:
    {
      programs.git = {
        enable = true;

        settings.user = {
          name = "Remi Gelinas";
          email = lib.mkDefault "mail@remigelin.as";
        };

        signing = {
          signByDefault = true;
          format = "ssh";
          key = lib.mkDefault "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIAmy0+X2k/t2PzeMAN537Tz+JNDLI3ozJpQSc9hnjb4n";
        };
      };

      programs.gh = {
        enable = true;

        extensions = [ pkgs.gh-poi ];
      };
    };
}
