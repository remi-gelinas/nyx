{
  flake.modules.homeManager.floorp =
    {
      config,
      lib,
      pkgs,
      ...
    }:
    lib.mkMerge [
      # On Linux the home-manager Floorp module (and its Firefox-derived
      # wrapper) works correctly.
      (lib.mkIf pkgs.stdenv.hostPlatform.isLinux {
        programs.floorp.enable = true;
      })

      (lib.mkIf pkgs.stdenv.hostPlatform.isDarwin {
        home.packages = [ pkgs.floorp-bin ];

        # copyApps places Floorp.app under "Home Manager Apps", and copying it
        # out of the nix store invalidates the bundle's code-signing seal, so we
        # ad-hoc re-sign it — otherwise Gatekeeper refuses to launch it.
        #
        # Do NOT rewrite the launcher script to exec the *local* binary: Floorp
        # 152 derives its sandbox app path from the binary it execs, and the
        # local path contains a space ("Home Manager Apps"), which makes it fail
        # to spawn its child processes and exit silently ~1s after launch with
        # no window.  Leaving the launcher pointed at the nix-store binary (a
        # space-free path) is what lets it run from the spaced copyApps dir.
        home.activation.resignFloorp = lib.hm.dag.entryAfter [ "copyApps" ] ''
          appDir="${config.home.homeDirectory}/${config.targets.darwin.copyApps.directory}/Floorp.app"
          if [ -d "$appDir" ]; then
            run /usr/bin/codesign --force --deep --sign - "$appDir"
          fi
        '';
      })
    ];
}
