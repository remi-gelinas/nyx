{
  flake.modules.darwin.onepassword = {
    programs._1password.enable = true;
    programs._1password-gui.enable = true;
  };

  flake.modules.homeManager.onepassword =
    { pkgs, lib, ... }:
    lib.mkMerge [
      {
        programs.git.settings.gpg.ssh.program = lib.mkDefault (
          if pkgs.stdenv.hostPlatform.isDarwin then
            "/Applications/1Password.app/Contents/MacOS/op-ssh-sign"
          else
            "op-ssh-sign"
        );
      }
      (lib.mkIf pkgs.stdenv.hostPlatform.isDarwin {
        programs.ssh.extraConfig = ''
          Host *
            IdentityAgent "~/Library/Group Containers/2BUA8C4S2C.com.1password/t/agent.sock"
        '';
      })
      (lib.mkIf pkgs.stdenv.hostPlatform.isLinux {
        programs.ssh.extraConfig = ''
          Host *
            IdentityAgent ~/.1password/agent.sock
        '';
      })
    ];
}
