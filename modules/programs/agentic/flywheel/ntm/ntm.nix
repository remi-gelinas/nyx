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

      # Two seeded sections; ntm's config is user-owned and ntm writes to it
      # (`ntm config set`), so these are seed-appends like the codex config,
      # not a store symlink — each section is added only when the file lacks
      # it, otherwise the user's settings are left alone.
      #
      # [recovery]: spawn-time "smart session recovery" builds its context
      # (agent-mail inbox + reservations, beads, checkpoints) under a
      # HARDCODED 5s deadline, and blowing it aborts the entire spawn
      # ("spawn recovery canceled: context deadline exceeded") — agents
      # never launch. The chain of MCP round-trips makes that budget
      # unreliable, and the flywheel doesn't need spawn injection anyway:
      # fresh agents pull work from the bead frontier.
      #
      # [agents]: ntm's compiled-in codex template defaults
      # model_reasoning_effort to "ultra", and that explicit -c flag
      # overrides the sol/high defaults in ~/.codex/config.toml on every
      # spawn. Same template as upstream with the effort default set to
      # high; an explicit --cod=N:model:effort spec still wins. (codex's
      # separate fast_mode feature flag is disabled via the codex config
      # seed in agent-mail.nix — effort and fast are independent knobs.)
      home.activation.ntmConfigSeed = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
        cfg="$HOME/.config/ntm/config.toml"
        recovery=${
          pkgs.writeText "ntm-recovery.toml" ''

            [recovery]
            auto_inject_on_spawn = false
          ''
        }
        agents=${
          pkgs.writeText "ntm-agents.toml" ''

            [agents]
            codex = '{{if .SystemPromptFile}}CODEX_SYSTEM_PROMPT="$(cat {{shellQuote .SystemPromptFile}})" {{end}}codex --dangerously-bypass-approvals-and-sandbox -m {{shellQuote (.Model | default "gpt-5.6-sol")}} -c model_reasoning_effort={{shellQuote (.ReasoningEffort | default "high")}} -c model_reasoning_summary_format=experimental --search'
          ''
        }
        run mkdir -p "$HOME/.config/ntm"
        [ -e "$cfg" ] || run touch "$cfg"
        if ! ${pkgs.gnugrep}/bin/grep -q '^\[recovery\]' "$cfg"; then
          run sh -c 'cat "$1" >> "$2"' _ "$recovery" "$cfg"
        fi
        if ! ${pkgs.gnugrep}/bin/grep -q '^\[agents\]' "$cfg"; then
          run sh -c 'cat "$1" >> "$2"' _ "$agents" "$cfg"
        fi
      '';
    };
}
