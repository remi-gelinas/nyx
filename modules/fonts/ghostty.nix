{
  flake.modules.homeManager.fonts-ghostty =
    { config, ... }:
    {
      programs.ghostty.settings.font-family = config.fonts.monospace.family;
    };
}
