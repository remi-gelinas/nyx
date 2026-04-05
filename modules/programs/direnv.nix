{
  flake.modules.homeManager.direnv =
    { pkgs, ... }:
    {
      programs.direnv = {
        enable = true;
        nix-direnv.enable = true;

        # TODO: Remove once NixOS/nixpkgs#507531 is resolved
        package = pkgs.direnv.overrideAttrs (_: {
          doCheck = false;
        });
      };
    };
}
