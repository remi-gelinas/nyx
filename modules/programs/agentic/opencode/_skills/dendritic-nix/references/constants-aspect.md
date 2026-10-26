# Constants (Shared Values) Aspect

Uses the `generic` class to define custom options that share values across all configuration classes.

## When to use

When you need to share values (usernames, email addresses, timezone, network settings) across multiple classes without using `specialArgs`. This replaces the traditional `specialArgs`/`extraSpecialArgs` pattern.

## Structure

```nix
{
  flake.modules.generic.systemConstants = { lib, ... }: {
    options.systemConstants = lib.mkOption {
      type = lib.types.attrs;
    };
    config.systemConstants = {
      timezone = "America/Montreal";
      adminEmail = "admin@example.org";
    };
  };
}
```

Consuming the constants in another module:

```nix
{
  flake.modules.nixos.timezone = { config, ... }: {
    time.timeZone = config.systemConstants.timezone;
  };
}
```

## Key points

- The `generic` class is shared across all other classes — anything defined there is available everywhere
- Define custom options with `lib.mkOption` so values are type-checked
- Access shared values via `config.<optionName>` in any class-level module
- This completely replaces `specialArgs`/`extraSpecialArgs` — never use those in Dendritic configs
