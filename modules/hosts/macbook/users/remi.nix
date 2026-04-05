{
  flake.modules.darwin.macbook-remi =
    { lib, ... }:
    {
      system.primaryUser = lib.mkDefault "remi";
    };
}
