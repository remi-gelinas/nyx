{
  flake.modules.homeManager.nord-opencode = {
    # opencode ships a built-in nord theme, so no palette port. v2 reads TUI
    # settings from cli.json (the home-manager `tui` option writes tui.json,
    # which v2 ignores); its schema takes theme as { name, mode } — a bare
    # string is silently ignored.
    xdg.configFile."opencode/cli.json".text = builtins.toJSON {
      "$schema" = "https://opencode.ai/v2/cli.json";
      theme.name = "nord";
    };
  };
}
