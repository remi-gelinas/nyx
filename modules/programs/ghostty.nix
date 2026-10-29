{
  flake.modules.homeManager.ghostty =
    { pkgs, ... }:
    {
      programs.ghostty = {
        enable = true;
        # 26.05 and nixos-unstable both pin 1.3.1; 1.4.0 (2026-10-27) fixes
        # 10 security advisories. ghostty-bin is a hash-pinned DMG fetch.
        package = pkgs.master.ghostty-bin;

        settings = {
          font-size = 19;
          window-vsync = false;
          window-decoration = false;
        };
      };
    };
}
