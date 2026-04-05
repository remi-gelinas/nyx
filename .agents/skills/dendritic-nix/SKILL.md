---
name: dendritic-nix
description: "Edit and create Nix flake configuration files following the Dendritic pattern — a feature-centric, flake-parts-based approach where every .nix file is a top-level module and code is organized by feature rather than by host. Use this skill whenever the user asks to add, modify, or configure anything in a Nix flake that uses import-tree, flake-parts with flake.modules, or the Dendritic pattern. Also trigger when the user mentions nix-darwin, home-manager modules, NixOS modules, or system configuration in a repo that has a modules/ directory with .nix files auto-imported by import-tree."
---

# Dendritic Nix Configuration

The Dendritic pattern structures Nix flake configurations around two core ideas:

1. **Every `.nix` file is a top-level flake-parts module.** There are no "NixOS module files" vs "home-manager module files" — all files share the same type.
2. **Code is organized by feature, not by host.** Each file defines a feature (e.g., `ssh`, `ghostty`, `bob`) containing settings for that feature across all relevant configuration classes (NixOS, Darwin, home-manager).

This flips the traditional host-centric approach: instead of "host → services → users", you get "feature → all classes that need it".

## Before You Edit

Before making any changes, read the project's `flake.nix` and a few existing modules under `modules/` to learn the project's specific conventions — input names, class names used, naming style, directory layout. Match them exactly.

Before making assumptions about what software or tools the user has, read their existing modules. For example, don't configure a browser extension for Chromium if there's no Chromium anywhere in their config — check what's actually present and tailor accordingly.

## Architecture

```
flake.nix                              # Minimal: inputs + import-tree call
modules/                               # All .nix files here, auto-imported recursively
  flake-parts.nix                      # Imports flake-parts.flakeModules.modules
  hosts/<hostname>/
    configuration.nix                  # Host aspect: imports other aspects
    flake-parts.nix                    # Boilerplate: flake.darwinConfigurations / nixosConfigurations
    users/<username>.nix               # Per-host user binding
  programs/<name>/<name>.nix           # Program features
  services/<name>/<name>.nix           # Service features
  users/<username>/<username>.nix      # User features: imports program/service aspects
  nix/                                 # Nix tooling and framework setup
```

Files/directories prefixed with `_` are excluded from import-tree (useful for WIP).

## Key Concepts

**Classes** — configuration contexts: `nixos`, `darwin`, `homeManager`, `generic` (cross-class shared).

**Aspects** — named modules at `flake.modules.<class>.<name>`. The fundamental building block. Multiple files can contribute to the same aspect name via `deferredModule` merge semantics. Aspects can use dot-separated namespaces (e.g., `programs.agentic`).

**Features** — one or more aspects forming a semantic unit (e.g., "ghostty" or "remi"). Can be a single file or a directory.

**Aspect naming** — names must be valid Nix identifiers to work with `with` expressions. Names starting with a digit (like `1password`) require quoting and break `with` scoping. Instead spell out the digit (`onepassword`), use an underscore prefix (`_1password`), or pick a descriptive name.

## Module Structure

Every `.nix` file under `modules/` is a flake-parts module. The outer structure is always:

```nix
# Simple: no inputs needed
{ flake.modules.<class>.<name> = { /* module body */ }; }

# With inputs:
{ inputs, ... }: { flake.modules.<class>.<name> = { /* module body */ }; }

# Inner function for pkgs/lib/config:
{ flake.modules.<class>.<name> = { pkgs, lib, config, ... }: { /* config */ }; }
```

The outer scope receives **flake-parts args** (`inputs`, `self`, `lib`). The inner function receives **class-level module args** (`pkgs`, `config`). These are different scopes.

## Patterns — Read the Right Reference

Pick the reference that matches your task:

| Situation | Reference |
|-----------|-----------|
| Adding a program or service to one class | `references/simple-aspect.md` |
| Feature spanning darwin + homeManager (or multiple classes) | `references/cross-class-feature.md` |
| Adding or modifying a host (machine) | `references/host-configuration.md` |
| Adding or modifying a user's programs | `references/user-feature.md` |
| Wrapping a third-party flake input's module | `references/importing-external-modules.md` |
| Platform-conditional config (Linux vs Darwin) | `references/conditional-aspect.md` |
| Sharing values across classes (replacing specialArgs) | `references/constants-aspect.md` |

Read the relevant reference(s) before writing code. For simple tasks, one reference may suffice. For complex features, you may need to combine patterns.

## Rules

1. **Every `.nix` file under `modules/` must be a flake-parts module.** No exceptions.

2. **Use `flake.modules.<class>.<name>` for all reusable config.** Aspects are definitions only — they become active when imported.

3. **Compose with `imports`, not `enable`.** Importing an aspect activates it: `imports = with self.modules.darwin; [ ssh syncthing ];`

4. **Never use `specialArgs` or `extraSpecialArgs`.** Use the Constants pattern instead (see `references/constants-aspect.md`).

5. **Imports must be unconditional.** Never wrap `imports` in `lib.mkIf`. Use `lib.mkIf` on config content inside the module instead.

6. **Use `lib.mkMerge`, not `//`.** Attribute set override does not recursively merge and silently loses nested data.

7. **Match existing conventions.** Read before writing. Use the same naming, structure, and patterns already present.

8. **Keep `flake.nix` minimal.** Only inputs and the `import-tree` call. Everything else belongs in `modules/`.

9. **One feature per file (or directory).** Don't combine unrelated features.

10. **Prefer nixpkgs packages over homebrew.** Homebrew should only be a last resort for packages genuinely unavailable in nixpkgs.

11. **Aspect names must be valid Nix identifiers.** Avoid names starting with a digit.

## Adding a New Feature — Checklist

1. Decide which classes need config (darwin? homeManager? both?)
2. Read the relevant pattern reference(s) from the table above
3. Create `modules/<category>/<name>/<name>.nix`
4. Write the flake-parts module with `flake.modules.<class>.<name>` for each class
5. If it wraps a flake input, add the input to `flake.nix` and use `{ inputs, ... }:` in the outer scope
6. If it needs `pkgs` or other module args, put those in the inner function, not the outer one
7. **Ask before wiring.** After creating the feature file, look through existing modules (host configurations, user features) to identify where the new aspect could be imported — then present those options to the user and let them decide. Do not automatically add imports to existing files without confirmation.
