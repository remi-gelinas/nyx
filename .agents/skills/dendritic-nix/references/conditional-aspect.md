# Conditional (Platform-Dependent) Aspect

A single aspect that behaves differently depending on the platform, using `lib.mkMerge` and `lib.mkIf`.

## When to use

When you have a homeManager aspect that needs different config on Linux vs Darwin, or any module that needs conditional behavior based on runtime properties.

## Structure

```nix
{
  flake.modules.homeManager.browser = { pkgs, lib, ... }:
    lib.mkMerge [
      {
        # shared config across all platforms
        programs.firefox.enable = true;
      }
      (lib.mkIf pkgs.stdenv.isLinux {
        # linux-specific
        programs.firefox.package = pkgs.firefox;
      })
      (lib.mkIf pkgs.stdenv.isDarwin {
        # darwin-specific
        programs.firefox.package = pkgs.firefox-bin;
      })
    ];
}
```

## Key points

- Use `lib.mkMerge` to combine conditional blocks — never use `//` (attribute set override) as it doesn't merge recursively
- Use `lib.mkIf` on the config content, never on `imports` — Nix requires imports to be unconditional
- `pkgs.stdenv.isLinux` and `pkgs.stdenv.isDarwin` are the standard platform checks
- This pattern is for a single aspect that varies by platform. If the config is entirely different between classes, use separate aspects in a cross-class feature instead
