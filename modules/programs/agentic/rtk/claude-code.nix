{
  flake.modules.homeManager.rtk-claude-code =
    { lib, pkgs, ... }:
    {
      programs.claude-code.settings.hooks.PreToolUse = [
        {
          matcher = "Bash";
          hooks = [
            {
              type = "command";
              command = "${lib.getExe pkgs.master.rtk} hook claude";
            }
          ];
        }
      ];
    };
}
