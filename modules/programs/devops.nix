{
  flake.modules.homeManager.devops =
    { pkgs, lib, ... }:
    {
      home.packages =
        with pkgs;
        [
          nodejs
          pulumi
          pulumiPackages.pulumi-nodejs
          pulumiPackages.pulumi-python
          dive
        ]
        ++ (lib.optionals pkgs.stdenv.hostPlatform.isDarwin [ orbstack ])
        ++ (lib.optionals pkgs.stdenv.hostPlatform.isLinux [ kubectl ]);
    };
}
