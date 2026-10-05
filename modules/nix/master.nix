{ inputs, ... }:
{
  flake.modules.generic.master =
    { pkgs, ... }:
    {
      nixpkgs.overlays = [
        (final: prev: {
          master = import inputs.nixpkgs-master {
            inherit (prev) config;
            inherit (prev.stdenv.hostPlatform) system;
          };
        })
      ];
    };
}
