{
  flake.modules.homeManager.nord-opencode = {
    # opencode ships a built-in nord theme, so no palette port. v2 reads TUI
    # settings from cli.json (the home-manager `tui` option writes tui.json,
    # which v2 ignores).
    xdg.configFile."opencode/cli.json".text = builtins.toJSON {
      "$schema" = "https://opencode.ai/cli.json";
      theme = "nord";
    };
  };
}
