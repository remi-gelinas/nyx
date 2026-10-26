# User Feature

A user is a feature that composes program and service aspects for a specific person. It defines what tools, programs, and settings a user gets.

## When to use

When adding a new user or modifying what programs/services a user has access to.

## Structure

```nix
# modules/users/remi/remi.nix
{ self, ... }: {
  flake.modules.homeManager.remi = {
    imports = with self.modules.homeManager; [
      programs.agentic
      zed
      ghostty
    ];
  };
}
```

A user can also define Darwin-level config (e.g., for system-level user settings):

```nix
{ self, ... }: {
  flake.modules.darwin.remi = {
    users.users.remi = {
      home = "/Users/remi";
      shell = "/run/current-system/sw/bin/fish";
    };
  };

  flake.modules.homeManager.remi = {
    imports = with self.modules.homeManager; [
      programs.agentic
      zed
      ghostty
    ];
  };
}
```

## Key points

- Users are bound to hosts via small files in `hosts/<hostname>/users/` (see host-configuration reference)
- The user feature defines the user's programs; the host binding activates the user on that machine
- Use `with self.modules.homeManager;` to import aspects by name without repeating the full path
