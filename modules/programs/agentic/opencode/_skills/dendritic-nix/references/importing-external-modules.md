# Importing External Modules

Wraps a flake input's module (NixOS module, Darwin module, home-manager module) as a Dendritic aspect.

## When to use

When integrating a third-party flake that provides its own module (e.g., `inputs.determinate.darwinModules.default`).

## Structure

```nix
# modules/nix/determinate/determinate.nix
{ inputs, ... }: {
  flake.modules.darwin.determinate = {
    imports = [ inputs.determinate.darwinModules.default ];
    determinateNix.enable = true;
  };
}
```

For a flake that provides modules for multiple classes:

```nix
{ inputs, ... }: {
  flake.modules.darwin.determinate = {
    imports = [ inputs.determinate.darwinModules.default ];
    determinateNix.enable = true;
  };

  flake.modules.nixos.determinate = {
    imports = [ inputs.determinate.nixosModules.default ];
    determinateNix.enable = true;
  };
}
```

## Key points

- The outer function must take `inputs` (or destructure specific inputs) since it needs to reference flake inputs
- The flake input itself must be declared in `flake.nix`
- The `imports` inside the aspect pulls in the external module; additional config (like `enable = true`) goes alongside it
- Common module attribute paths: `inputs.<name>.darwinModules.default`, `inputs.<name>.nixosModules.default`, `inputs.<name>.homeManagerModules.default`
- If the external module only exists for certain classes, only create aspects for those classes
