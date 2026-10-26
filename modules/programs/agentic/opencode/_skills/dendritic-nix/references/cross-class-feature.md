# Cross-Class Feature

A single file defining the same feature for multiple classes, often sharing logic between them.

## When to use

When a feature needs to exist at both the system level (darwin/nixos) and user level (homeManager), or across multiple system classes. For example, a program that needs a system package installed AND user-level configuration.

## Structure

Using a shared helper to avoid repetition:

```nix
# modules/programs/agentic/agentic.nix
let
  pkgsFor = key: { pkgs, ... }: {
    ${key} = with pkgs; [ claude-code-bin opencode ];
  };
in {
  flake.modules.darwin.programs.agentic = pkgsFor "environment.systemPackages";
  flake.modules.homeManager.programs.agentic = pkgsFor "home.packages";
}
```

With distinct config per class:

```nix
{
  flake.modules.darwin.onepassword = { pkgs, ... }: {
    environment.systemPackages = with pkgs; [
      _1password-gui
      _1password-cli
    ];
  };

  flake.modules.homeManager.onepassword = {
    programs.firefox.policies.ExtensionSettings."onepassword-password-manager@AgileBits" = {
      install_url = "https://addons.mozilla.org/firefox/downloads/latest/1password-x-password-manager/latest.xpi";
      installation_mode = "force_installed";
    };
  };
}
```

## Key points

- All aspects for a feature live in the same file — this keeps the feature self-contained
- Use `let` bindings to share logic between classes when the config is structurally similar
- Aspect names can use dot-separated namespaces (e.g., `programs.agentic`) to organize within a class
- Before configuring user-level tools (browser extensions, editor plugins), check the user's existing modules to see what they actually have installed
