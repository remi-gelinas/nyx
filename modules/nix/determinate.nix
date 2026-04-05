{
  inputs,
  ...
}:
{
  flake.modules.darwin.determinate = {
    imports = [ inputs.determinate.darwinModules.default ];

    determinateNix = {
      enable = true;

      customSettings = {
        lazy-trees = true;
        eval-cores = 0;
      };
    };
  };

  flake.modules.homeManager.determinate = {
    imports = [ inputs.determinate.homeManagerModules.default ];
  };
}
