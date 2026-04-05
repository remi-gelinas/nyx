# Simple Aspect

A standalone feature with independent config for one or more classes. Each class gets its own aspect, but they live in the same file.

## When to use

Adding a single program, service, or setting that doesn't need to coordinate between classes. The most common pattern — start here unless you need something more specific.

## Structure

```nix
{
  flake.modules.darwin.bluetooth = {
    hardware.bluetooth.enable = true;
  };
}
```

With module arguments (when you need `pkgs`, `lib`, `config`, etc.):

```nix
{
  flake.modules.homeManager.ghostty = { pkgs, ... }: {
    programs.ghostty = {
      enable = true;
      package = pkgs.ghostty-bin;
    };
  };
}
```

Multiple classes in one file:

```nix
{
  flake.modules.darwin.ssh = {
    services.openssh.enable = true;
  };

  flake.modules.homeManager.ssh = { ... }: {
    programs.ssh.enable = true;
  };
}
```

## Key points

- The outer structure is always a flake-parts module (plain attr set or `{ inputs, ... }:` function)
- The inner value can be a plain attr set (static config) or a function (`{ pkgs, ... }:`) when you need module arguments
- These are two different scopes: outer gets flake-parts args (`inputs`, `self`), inner gets class-level args (`pkgs`, `lib`, `config`)
- Place the file at `modules/<category>/<name>/<name>.nix` (e.g., `modules/programs/ghostty/ghostty.nix`)
