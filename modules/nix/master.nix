{ inputs, ... }:
{
  flake.modules.generic.master =
    { pkgs, ... }:
    {
      nixpkgs.overlays = [
        (final: prev: {
          master = import inputs.nixpkgs-master {
            inherit (prev) system config;
          };
        })
      ];
    };
}
