{ inputs, self, ... }:
{
  flake.modules.generic.fonts-pragmata-pro =
    { lib, pkgs, ... }:
    let
      pkg = inputs.fonts.packages.${pkgs.stdenv.hostPlatform.system}.pragmata-pro-variable;
    in
    {
      fonts.monospace = {
        family = lib.mkDefault "PragmataPro VF Mono Liga";
        package = lib.mkDefault pkg;
      };

      fonts.proportional = {
        family = lib.mkDefault "PragmataPro VF";
        package = lib.mkDefault pkg;
      };
    };

  flake.modules.homeManager.fonts-pragmata-pro.imports = [
    self.modules.homeManager.fonts-base
    self.modules.generic.fonts-pragmata-pro
  ];
}
