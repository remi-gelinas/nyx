{ self, ... }:
{
  flake.modules.generic.fonts =
    { lib, ... }:
    let
      fontOptionType = lib.types.submodule {
        options = {
          family = lib.mkOption {
            type = lib.types.str;
          };

          package = lib.mkOption {
            type = lib.types.package;
          };
        };
      };
    in
    {
      options.fonts = {
        monospace = lib.mkOption {
          type = fontOptionType;
        };

        proportional = lib.mkOption {
          type = fontOptionType;
        };
      };
    };

  flake.modules.homeManager.fonts-base =
    { config, lib, ... }:
    {
      imports = with self.modules; [
        generic.fonts
        homeManager.fonts-ghostty
        homeManager.fonts-zed
      ];

      home.packages =
        with config.fonts;
        lib.unique [
          monospace.package
          proportional.package
        ];
    };
}
