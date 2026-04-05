{
  flake.modules.homeManager.fonts-zed =
    { config, ... }:
    {
      programs.zed-editor.userSettings = with config.fonts; {
        buffer_font_family = monospace.family;
        ui_font_family = proportional.family;
      };
    };
}
