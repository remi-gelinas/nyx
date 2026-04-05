{ self, ... }:
let
  workspaces = {
    Code.key = "c";
    Terminal.key = "t";
    Web.key = "w";
    Social.key = "s";
  };
in
{
  flake.modules.darwin.aerospace =
    { lib, pkgs, ... }:
    let
      workspaceBindings = lib.mapAttrs' (
        workspace: { key, ... }: lib.nameValuePair "alt-${key}" "workspace ${workspace}"
      ) workspaces;

      moveToWorkspaceBindings = lib.mapAttrs' (
        workspace: { key, ... }: lib.nameValuePair "alt-shift-${key}" "move-node-to-workspace ${workspace}"
      ) workspaces;
    in
    {
      services.aerospace = {
        enable = true;

        package = pkgs.unstable.aerospace;

        settings = {
          mode.main.binding = lib.mkMerge [
            workspaceBindings
            moveToWorkspaceBindings
          ];
        };
      };
    };
}
