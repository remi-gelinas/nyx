{
  inputs,
  self,
  lib,
  ...
}:
{
  flake.darwinConfigurations.macbook = inputs.nix-darwin.lib.darwinSystem {
    modules = [
      self.modules.darwin.macbook
      {
        nixpkgs.hostPlatform = lib.mkDefault "aarch64-darwin";
        system.stateVersion = 6;
      }
    ];
  };
}
