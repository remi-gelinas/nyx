{
  flake.modules.homeManager.omp-zed =
    { config, lib, ... }:
    {
      programs.zed-editor.userSettings.agent_servers.OMP = {
        type = "custom";
        command = lib.getExe config.programs.omp.package;
        args = [ "acp" ];
      };
    };
}
