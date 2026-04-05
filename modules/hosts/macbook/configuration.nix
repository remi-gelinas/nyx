{ self, ... }:
{
  flake.modules.darwin.macbook = {
    imports = with self.modules.darwin; [
      macbook-remi
      determinate
      aerospace
      onepassword
      fish
      system
      self.modules.generic.unfree
      self.modules.generic.unstable
      self.modules.generic.master
    ];
  };
}
