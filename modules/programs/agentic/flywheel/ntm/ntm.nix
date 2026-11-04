{
  flake.modules.homeManager.flywheel =
    {
      config,
      pkgs,
      lib,
      ...
    }:
    let
      sources = import ./_sources.nix { inherit (pkgs) fetchFromGitHub; };
      riderLicense = import ../_rider-license.nix;

      # ntm shells out to tmux and to the agent CLI (opencode) at runtime.
      # tmux is wrapped onto its PATH from nixpkgs; the agent CLI is
      # deliberately left off the wrapper PATH so ntm resolves whichever
      # one the user's own session already provides.
      # v1.31.0's go.mod requires go >= 1.26.5; the 26.05 and unstable pins
      # both carry 1.26.4, master 1.26.5.
      ntm = pkgs.buildGoModule.override { go = pkgs.master.go; } {
        pname = "ntm";
        inherit (sources.ntm) version src vendorHash;

        # ntm's opencode idle check reads only the last 5 pane lines, which
        # fits the v1 TUI. In v2 the idle chrome sits higher, so panes never
        # read as ready and spawn-time --prompt delivery times out.
        patches = [ ./_opencode-v2-idle.patch ];

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

      # Reuse upstream's OMP readiness patterns and model/thinking arguments.
      # Only the autonomy flag differs from its interactive launch template.
      xdg.configFile."ntm/agents/omp.toml" = lib.mkIf config.programs.omp.enable {
        source = pkgs.runCommand "ntm-omp.toml" { } ''
          sed 's/command = "omp/command = "omp --yolo/' ${sources.ntm.src}/examples/agents/omp.toml > $out
        '';
      };

      # The swarm supervisor (flywheel-supervise). No system_prompt: the prompt
      # lives in the opencode agent the persona name selects, and ntm refuses
      # a persona prompt file the oc template does not consume. Opus because
      # the supervisor's real job is judging drift, and one pane of the
      # strongest model costs little next to a swarm working the wrong thing.
      xdg.configFile."ntm/personas.toml".source = (pkgs.formats.toml { }).generate "ntm-personas.toml" {
        personas = [
          {
            name = "supervisor";
            description = "Keeps a flywheel swarm on track without doing its work";
            agent_type = "opencode";
            model = "openrouter/anthropic/claude-opus-5.5";
          }
        ];
      };

      # ntm's fish integration (command palette keybinding, completions,
      # session helpers) — upstream's documented `ntm shell fish | source`,
      # run once per interactive shell rather than hand-edited into config.fish.
      programs.fish.interactiveShellInit = ''
        ${ntm}/bin/ntm shell fish | source
      '';

      # Seeded sections; ntm's config is user-owned and ntm writes to it
      # (`ntm config set`), so these are seed-appends, not a store symlink —
      # each section is added only when the file lacks it, otherwise the
      # user's settings are left alone.
      #
      # [recovery]: spawn-time "smart session recovery" builds its context
      # (agent-mail inbox + reservations, beads, checkpoints) under a
      # HARDCODED 5s deadline, and blowing it aborts the entire spawn
      # ("spawn recovery canceled: context deadline exceeded") — agents
      # never launch. The chain of MCP round-trips makes that budget
      # unreliable, and the flywheel doesn't need spawn injection anyway:
      # fresh agents pull work from the bead frontier.
      #
      # [agents]: the oc launch line is added by
      # the per-key insert below (so it also lands on a pre-existing [agents]
      # section); this seed just creates the header on a fresh config.
      home.activation.ntmConfigSeed = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
        cfg="$HOME/.config/ntm/config.toml"
        recovery=${pkgs.writeText "ntm-recovery.toml" ''

          [recovery]
          auto_inject_on_spawn = false
        ''}
        agents=${pkgs.writeText "ntm-agents.toml" ''

          [agents]
        ''}
        integrations=${pkgs.writeText "ntm-integrations.toml" ''

          [integrations.dcg]
          enabled = false

          [integrations.rch]
          enabled = false
        ''}
        # [coordinator]: these match ntm's defaults today and are pinned so an
        # upstream default change cannot turn them on. auto_assign claims beads
        # and mails them to idle panes, while the flywheel plugin makes those
        # same panes claim from the frontier: one agent ends up holding two
        # beads, and its assignment mail tells agents to commit `.beads/`.
        # mail_nudge would type into panes the plugin already nudges.
        coordinator=${pkgs.writeText "ntm-coordinator.toml" ''

          [coordinator]
          auto_assign = false
          mail_nudge = false
          conflict_notify = true
          conflict_negotiate = false
          send_digests = false
        ''}
        contextLimits=${pkgs.writeText "ntm-context-limits.toml" ''
          "openrouter/z-ai/glm-5.3" = 1048576
          "openrouter/z-ai/glm-5.3-flash" = 1048576
          "openrouter/anthropic/claude-opus-5.5" = 1000000
          "openrouter/anthropic/claude-fable-5.1" = 1000000
          "openrouter/openai/gpt-6.1-sol" = 1050000
          "openrouter/deepseek/deepseek-v4.1-flash" = 1048576
        ''}
        run mkdir -p "$HOME/.config/ntm"
        [ -e "$cfg" ] || run touch "$cfg"
        if ! ${pkgs.gnugrep}/bin/grep -q '^\[recovery\]' "$cfg"; then
          run sh -c 'cat "$1" >> "$2"' _ "$recovery" "$cfg"
        fi
        if ! ${pkgs.gnugrep}/bin/grep -q '^\[agents\]' "$cfg"; then
          run sh -c 'cat "$1" >> "$2"' _ "$agents" "$cfg"
        fi
        # The [agents] section seed above only fires on a file that lacks the
        # header, so the oc key is a per-key insert (covers a pre-existing
        # [agents] too). ntm's compiled-in oc template passes --model, a flag
        # the v2 root CLI no longer has — so the model rides --fw-model, a
        # sentinel the fish wrapper strips into an OPENCODE_CONFIG_CONTENT
        # model override. Bare --oc=N omits it and falls through
        # to opencode.json's default. Swarm panes need --standalone (v2's
        # shared daemon would run every pane's tools under one env — per-pane
        # AGENT_NAME dies with it) and --auto (auto-approve; explicit deny
        # policies and the dcg bridge still apply). Identity + model export
        # ride the fish opencode wrapper.
        # Reconcile, not just insert: the oc line is entirely ours (no user
        # tuning), so replace an existing one to pick up template changes
        # across switches; insert under the header on a fresh config.
        # A persona name rides --fw-agent the same way, so `--persona=<name>`
        # launches the opencode agent of that name.
        oc=${lib.escapeShellArg "oc = 'opencode --standalone --auto{{if .Model}} --fw-model {{shellQuote .Model}}{{end}}{{if .PersonaName}} --fw-agent {{shellQuote .PersonaName}}{{end}}'"}
        if ${pkgs.gnugrep}/bin/grep -qE '^oc = ' "$cfg"; then
          run ${pkgs.gnused}/bin/sed -i "s|^oc = .*|$oc|" "$cfg"
        else
          run ${pkgs.gnused}/bin/sed -i "/^\[agents\]/a $oc" "$cfg"
        fi
        # ntm's dcg/rch integrations inject a hooks env blob into agent launch
        # lines. rch (remote compilation offload) is not packaged here, so its
        # hook would invoke a missing binary on every Bash call, and dcg runs
        # through the opencode plugin's execute.before bridge — the injection
        # only bloats the typed command past what panes reliably parse. Spawns
        # with these off launch clean; with them on, panes died at the prompt.
        if ! ${pkgs.gnugrep}/bin/grep -q '^\[integrations' "$cfg"; then
          run sh -c 'cat "$1" >> "$2"' _ "$integrations" "$cfg"
        fi
        if ! ${pkgs.gnugrep}/bin/grep -q '^\[coordinator\]' "$cfg"; then
          run sh -c 'cat "$1" >> "$2"' _ "$coordinator" "$cfg"
        fi
        # ntm's registry has no entries for the vendor-prefixed slugs opencode
        # runs through OpenRouter, so their windows fall to the 128k default
        # without these overrides. Per-key: the section is created once, then
        # every key the file lacks is inserted under its header, so models
        # added later still land. A key the user already has keeps its value.
        if ! ${pkgs.gnugrep}/bin/grep -q '^\[models\.context_limits\]' "$cfg"; then
          run sh -c 'printf "\n[models.context_limits]\n" >> "$1"' _ "$cfg"
        fi
        while IFS= read -r line; do
          key=''${line%% = *}
          [ -n "$key" ] || continue
          if ! ${pkgs.gnugrep}/bin/grep -qF -- "$key = " "$cfg"; then
            run ${pkgs.gnused}/bin/sed -i "/^\[models\.context_limits\]/a $line" "$cfg"
          fi
        done < "$contextLimits"
      '';
    };
}
