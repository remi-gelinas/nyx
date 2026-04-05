# Host Configuration

A host is a feature that composes other aspects via imports. Each host gets its own directory with at least two files: a configuration and a flake-parts boilerplate file.

## When to use

When adding a new machine (NixOS host, Darwin mac, etc.) or modifying an existing host's composition.

## Structure

### Configuration file — defines the host aspect

```nix
# modules/hosts/macbook/configuration.nix
{ self, ... }: {
  flake.modules.darwin.macbook = {
    imports = with self.modules.darwin; [
      determinate
      programs.agentic
    ];
  };
}
```

For NixOS:

```nix
# modules/hosts/server/configuration.nix
{ self, ... }: {
  flake.modules.nixos.server = {
    imports = with self.modules.nixos; [
      determinate
    ];
  };
}
```

### Flake-parts boilerplate — exposes the host as a system configuration

Darwin:

```nix
# modules/hosts/macbook/flake-parts.nix
{ inputs, self, lib, ... }: {
  flake.darwinConfigurations.macbook = inputs.nix-darwin.lib.darwinSystem {
    modules = [
      self.modules.darwin.macbook
      { nixpkgs.hostPlatform = lib.mkDefault "aarch64-darwin"; }
    ];
  };
}
```

NixOS:

```nix
# modules/hosts/server/flake-parts.nix
{ inputs, self, lib, ... }: {
  flake.nixosConfigurations.server = inputs.nixpkgs.lib.nixosSystem {
    modules = [
      self.modules.nixos.server
      {
        nixpkgs.hostPlatform = lib.mkDefault "x86_64-linux";
        system.stateVersion = "25.11";
      }
    ];
  };
}
```

### Binding users to a host

A small file in the host directory that imports the user's aspect:

```nix
# modules/hosts/macbook/users/remi.nix
{ self, ... }: {
  flake.modules.darwin.macbook = {
    imports = [ self.modules.darwin.remi ];
  };
}
```

## Key points

- The configuration file defines *what* the host imports; the flake-parts file defines *how* it's built
- Keep these in separate files — the flake-parts boilerplate rarely changes
- Use the correct class: `darwin` for macs, `nixos` for NixOS machines
- Use the correct builder: `inputs.nix-darwin.lib.darwinSystem` for darwin, `inputs.nixpkgs.lib.nixosSystem` for NixOS
- NixOS `stateVersion` is a string (`"25.11"`), Darwin `stateVersion` is an integer (`6`)
- Multiple files can contribute to the same host aspect — `deferredModule` merge handles it
- User binding files go in `hosts/<hostname>/users/`
