{
  flake.modules.homeManager.flywheel =
    { pkgs, lib, ... }:
    let
      sources = import ./_sources.nix { inherit (pkgs) fetchFromGitHub; };
      riderLicense = import ../_rider-license.nix;

      # ntm shells out to tmux and to the agent CLIs (claude/codex/gemini) at
      # runtime. tmux is wrapped onto its PATH from nixpkgs; the agent CLIs
      # are deliberately left off the wrapper PATH so ntm resolves whichever
      # ones the user's own session already provides.
      ntm = pkgs.buildGoModule {
        pname = "ntm";
        inherit (sources.ntm) version src vendorHash;

        subPackages = [ "cmd/ntm" ];
        doCheck = false;

        nativeBuildInputs = [ pkgs.makeWrapper ];

        postFixup = ''
          wrapProgram $out/bin/ntm --prefix PATH : ${pkgs.tmux}/bin
        '';

        # MIT with an OpenAI/Anthropic rider barring those vendors (and
        # anyone acting on their behalf) from any rights in the Software;
        # never lib.licenses.mit.
        meta = {
          mainProgram = "ntm";
          license = riderLicense // {
            url = "https://github.com/Dicklesworthstone/ntm/blob/v${sources.ntm.version}/LICENSE";
          };
        };
      };
    in
    {
      home.packages = [ ntm ];

      # ntm's fish integration (command palette keybinding, completions,
      # session helpers) — upstream's documented `ntm shell fish | source`,
      # run once per interactive shell rather than hand-edited into config.fish.
      programs.fish.interactiveShellInit = ''
        ${ntm}/bin/ntm shell fish | source
      '';

      # Spawn-time "smart session recovery" builds its context (agent-mail
      # inbox + reservations, beads, checkpoints) under a HARDCODED 5s
      # deadline, and blowing it aborts the entire spawn ("spawn recovery
      # canceled: context deadline exceeded") — agents never launch. The
      # chain of MCP round-trips makes that budget unreliable, and the
      # flywheel doesn't need spawn injection anyway: fresh agents pull work
      # from the bead frontier. ntm's config is user-owned and ntm writes to
      # it (`ntm config set`), so this is a seed-append like the codex
      # config, not a store symlink: add the [recovery] section only when
      # the file lacks one, otherwise leave the user's settings alone.
      home.activation.ntmConfigSeed = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
        cfg="$HOME/.config/ntm/config.toml"
        snippet=${
          pkgs.writeText "ntm-recovery.toml" ''

            [recovery]
            auto_inject_on_spawn = false
          ''
        }
        run mkdir -p "$HOME/.config/ntm"
        if [ ! -e "$cfg" ]; then
          run install -m644 "$snippet" "$cfg"
        elif ! ${pkgs.gnugrep}/bin/grep -q '^\[recovery\]' "$cfg"; then
          run sh -c 'cat "$1" >> "$2"' _ "$snippet" "$cfg"
        fi
      '';
    };
}
