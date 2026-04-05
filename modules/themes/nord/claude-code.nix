{
  flake.modules.homeManager.nord-claude-code =
    let
      # Official Nord palette (nordtheme.com): nord0-3 Polar Night,
      # nord4-6 Snow Storm, nord7-10 Frost, nord11-15 Aurora.
      nord1 = "#3B4252";
      nord2 = "#434C5E";
      nord3 = "#4C566A";
      nord4 = "#D8DEE9";
      nord7 = "#8FBCBB";
      nord8 = "#88C0D0";
      nord9 = "#81A1C1";
      nord10 = "#5E81AC";
      nord11 = "#BF616A";
      nord13 = "#EBCB8B";
      nord14 = "#A3BE8C";
      theme = {
        name = "nord";
        # dark-ansi inherits the terminal's Nord ANSI palette (nord-ghostty)
        # for everything not overridden here.
        base = "dark-ansi";
        overrides = {
          text = nord4;
          subtle = nord3;
          inactive = nord3;
          claude = nord8;
          claudeShimmer = nord7;
          permission = nord9;
          autoAccept = nord14;
          warning = nord13;
          error = nord11;
          promptBorder = nord2;
          promptBorderShimmer = nord8;
          bashBorder = nord10;
          userMessageBackground = nord1;
          # Diff backgrounds: nord0 blended toward the Aurora green/red at
          # 25% (full) and 15% (dimmed); word-level highlights use the
          # Aurora colors directly.
          diffAdded = "#4B5653";
          diffRemoved = "#523F4A";
          diffAddedDimmed = "#3F494B";
          diffRemovedDimmed = "#443B46";
          diffAddedWord = nord14;
          diffRemovedWord = nord11;
        };
      };
    in
    {
      home.file.".claude/themes/nord.json".text = builtins.toJSON theme;
      programs.claude-code.settings.theme = "custom:nord";
    };
}
