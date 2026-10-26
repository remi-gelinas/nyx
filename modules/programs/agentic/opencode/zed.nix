{
  flake.modules.homeManager.opencode-zed =
    { lib, pkgs, ... }:
    {
      programs.zed-editor.userSettings.agent_servers.OpenCode = {
        type = "custom";
        command = lib.getExe pkgs.master.opencode;
        args = [ "acp" ];
      };
    };
}
