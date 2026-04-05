{
  flake.modules.homeManager.nord-zed = {
    programs.zed-editor = {
      extensions = [ "nord" ];

      userSettings.theme = {
        mode = "system";
        dark = "Nord Dark";
        light = "Nord";
      };
    };
  };
}
