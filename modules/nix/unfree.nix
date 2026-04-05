{
  flake.modules.generic.unfree = {
    nixpkgs.config = import ./_nixpkgs-config.nix;
  };
}
