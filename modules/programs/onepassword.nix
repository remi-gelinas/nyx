{
  flake.modules.darwin.onepassword =
    { pkgs, ... }:
    {
      programs._1password.enable = true;
      programs._1password-gui = {
        enable = true;
        # nix-darwin rsyncs this package's 1Password.app into /Applications on
        # activation. Stable's _1password-gui is 8.12.21, older than the vault
        # data a newer build already migrated — so the app refuses to open
        # ("saved data appears newer than this version"). master tracks the
        # current release (8.12.42); pin the GUI there until stable catches up.
        package = pkgs.master._1password-gui;
      };
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
        programs.ssh.settings."*".IdentityAgent =
          ''"~/Library/Group Containers/2BUA8C4S2C.com.1password/t/agent.sock"'';
      })
      (lib.mkIf pkgs.stdenv.hostPlatform.isLinux {
        programs.ssh.settings."*".IdentityAgent = "~/.1password/agent.sock";
      })
    ];
}
