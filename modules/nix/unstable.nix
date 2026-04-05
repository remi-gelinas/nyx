{ inputs, ... }:
{
  flake.modules.generic.unstable =
    { pkgs, ... }:
    {
      nixpkgs.overlays = [
        (final: prev: {
          unstable = import inputs.nixpkgs-unstable {
            inherit (prev) system config;
          };
        })
      ];
    };
}
