{
  flake.modules.homeManager.zed =
    { pkgs, ... }:
    {
      # The zed CLI resolves its .app bundle from current_exe(), so it must
      # point through the Home Manager Apps copy — not the Nix store copy —
      # otherwise LSOpenFromURLSpec cannot route to the running instance.
      home.packages = [
        (pkgs.writeShellScriptBin "zed" ''
          exec ~/Applications/Home\ Manager\ Apps/Zed.app/Contents/MacOS/cli "$@"
        '')
      ];

      programs.zed-editor = {
        enable = true;
        package = pkgs.master.zed-editor;

        mutableUserSettings = false;
        installRemoteServer = true;

        extensions = [
          "nix"
          "gleam"
          "toml"
          "json5"
          "zig"
          "scss"
          "terraform"
          "elixir"
          "erlang"
          "helm"
        ];

        userSettings = {
          vim_mode = true;
          auto_update = false;
          load_direnv = "shell_hook";
          relative_line_numbers = "enabled";

          journal.hour_format = "hour24";

          buffer_font_size = 20;
          ui_font_size = 18;

          telemetry = {
            metrics = false;
          };

          title_bar = {
            show_branch_icon = false;
            show_onboarding_banner = false;
            show_user_picture = false;
          };

          toolbar = {
            breadcrumbs = false;
            quick_actions = false;
            selections_menu = false;
            agent_review = false;
          };

          agent.expand_terminal_card = false;
          chat_panel.button = false;

          languages."Nix".language_servers = [
            "nixd"
            "!nil"
          ];
        };
      };
    };
}
