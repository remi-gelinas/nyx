{
  inputs,
  self,
  ...
}:
let
  system = "aarch64-darwin";
  nixpkgsConfig = import ../../nix/_nixpkgs-config.nix;
in
{
  flake.homeConfigurations.remi = inputs.home-manager.lib.homeManagerConfiguration {
    pkgs = import inputs.nixpkgs {
      inherit system;
      config = nixpkgsConfig;
    };

    modules = [ self.modules.homeManager.remi ];
  };
}
