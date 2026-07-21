{
  flake.modules.homeManager.cliproxyapi =
    {
      config,
      pkgs,
      lib,
      ...
    }:
    let
      sources = import ./_sources.nix { inherit (pkgs) fetchFromGitHub; };

      cliproxyapi = pkgs.buildGoModule {
        pname = "cli-proxy-api";
        inherit (sources.cliproxyapi) version src vendorHash;
        subPackages = [ "cmd/server" ];
        doCheck = false;
        postInstall = "mv $out/bin/server $out/bin/cli-proxy-api";
      };

      # Only guards localhost:8317; management API and remote access are
      # disabled. Claude Code hardcodes claude-* ids for internal calls, so
      # alias them onto the Codex backend.
      localKey = "8cb56cff15456cad270eea1a543dc582574b1071c79d8783";
      # Tier map so team roles keep their provider-agnostic claude model
      # pins and land on the GPT equivalent: fable/opus -> sol,
      # sonnet -> terra, haiku -> luna.
      tierAliases = {
        "claude-fable-5[1m]" = "gpt-5.6-sol";
        "claude-fable-5" = "gpt-5.6-sol";
        "claude-opus-4-8" = "gpt-5.6-sol";
        "claude-sonnet-5" = "gpt-5.6-terra";
        "claude-sonnet-4-6" = "gpt-5.6-terra";
        "claude-haiku-4-5-20251001" = "gpt-5.6-luna";
      };
      configFile = (pkgs.formats.yaml { }).generate "cli-proxy-api-config" {
        host = "127.0.0.1";
        port = 8317;
        tls.enable = false;
        auth-dir = "~/.cli-proxy-api";
        api-keys = [ localKey ];
        remote-management = {
          allow-remote = false;
          disable-control-panel = true;
        };
        routing = {
          strategy = "round-robin";
          session-affinity = false;
        };
        oauth-model-alias.codex = pkgs.lib.mapAttrsToList (alias: name: {
          inherit name alias;
          fork = true;
        }) tierAliases;
      };

      # Claude Code's auto-compact bookkeeping doesn't know gpt-* model ids
      # and never triggers, so proxy sessions grow until they hit the real
      # window. At each turn end, if this is a proxy session in a tmux pane
      # with context past the threshold, type /compact into the pane the way
      # a user would. Native sessions and non-tmux sessions are gated out.
      autoCompact = pkgs.writeShellScript "claudex-auto-compact" ''
        payload=$(cat)
        {
          [ -n "$TMUX_PANE" ] || exit 0
          # Applies to proxy sessions (broken native bookkeeping) and to any
          # session in a team-marked tmux session — including claudem's
          # native lead, whose fable cache reads bill 2-4x the GPT tiers and
          # whose native auto-compact only fires near 1M.
          ok=0
          case "$ANTHROPIC_BASE_URL" in
            *127.0.0.1:8317*) ok=1 ;;
          esac
          if [ "$ok" != "1" ]; then
            [ "$(tmux display -t "$TMUX_PANE" -p "#{@claude_team}" 2>/dev/null)" = "1" ] && ok=1
          fi
          [ "$ok" = "1" ] || exit 0
          tp=$(printf '%s' "$payload" | ${lib.getExe pkgs.jq} -r '.transcript_path // empty')
          [ -n "$tp" ] && [ -f "$tp" ] || exit 0
          ctx=$(${lib.getExe pkgs.jq} -s '
            [ .[] | select(.message.usage) | .message.usage ] | last
            | (.input_tokens // 0) + (.cache_read_input_tokens // 0) + (.cache_creation_input_tokens // 0)' "$tp")
          [ "$ctx" -gt 150000 ] || exit 0
          # Text and Enter separately: sent together they paste-detect
          # into the composer instead of submitting.
          (
            sleep 1
            tmux send-keys -t "$TMUX_PANE" "/compact"
            sleep 1
            tmux send-keys -t "$TMUX_PANE" Enter
          ) &
        } 2>/dev/null || true
        exit 0
      '';
    in
    lib.mkMerge [
      {
        home.packages = [ cliproxyapi ];

        programs.claude-code.settings.hooks.Stop = [
          {
            hooks = [
              {
                type = "command";
                command = "${autoCompact}";
              }
            ];
          }
        ];

      # Stable copy for manual commands (-codex-login); launchd points at
      # the store path so config changes alter the plist and home-manager
      # restarts the agent on switch.
      xdg.configFile."cli-proxy-api/config.yaml".source = configFile;

      # GPT sessions in the Claude Code harness via the local proxy; plain
      # `claude` stays on Anthropic. Env mirrors the known-good claudex
      # recipe for non-Anthropic backends.
      programs.fish.functions.claudex = ''
        set -lx ANTHROPIC_BASE_URL http://127.0.0.1:8317
        set -lx ANTHROPIC_AUTH_TOKEN ${localKey}
        set -lx ANTHROPIC_SMALL_FAST_MODEL "gpt-5.6-luna[1m]"
        # No CLAUDE_CODE_SUBAGENT_MODEL: on 2.1.211+ it overrides teammate
        # model resolution entirely, flattening role pins and spawn-time
        # tiers. Tiering comes from the ANTHROPIC_DEFAULT_* mapping below.
        # Resolve tier aliases to GPT ids client-side, so haiku-tier
        # teammates identify as gpt-5.6-luna and skip claude-id-keyed
        # restrictions (e.g. no auto mode on haiku). The [1m] suffix makes
        # the client book the true 1M window (gauge and auto-compact);
        # it strips the suffix before the request hits the proxy.
        set -lx ANTHROPIC_DEFAULT_OPUS_MODEL "gpt-5.6-sol[1m]"
        set -lx ANTHROPIC_DEFAULT_SONNET_MODEL "gpt-5.6-terra[1m]"
        set -lx ANTHROPIC_DEFAULT_HAIKU_MODEL "gpt-5.6-luna[1m]"
        set -lx CLAUDE_CODE_ALWAYS_ENABLE_EFFORT 1
        set -lx ENABLE_TOOL_SEARCH false

        # Split-pane teammates are spawned by the tmux server, not the lead,
        # so they only see the tmux session environment. Push the proxy env
        # there while claude runs and remove it afterwards so later plain
        # `claude` panes stay on Anthropic.
        set -l proxy_vars ANTHROPIC_BASE_URL ANTHROPIC_AUTH_TOKEN \
          ANTHROPIC_SMALL_FAST_MODEL \
          ANTHROPIC_DEFAULT_OPUS_MODEL ANTHROPIC_DEFAULT_SONNET_MODEL \
          ANTHROPIC_DEFAULT_HAIKU_MODEL \
          CLAUDE_CODE_ALWAYS_ENABLE_EFFORT ENABLE_TOOL_SEARCH
        if set -q TMUX
            for v in $proxy_vars
                tmux set-environment $v $$v
            end
        end

        # Default the lead to sol, but honor an explicit --model in argv so
        # implementation-phase waves can run a cheaper lead tier.
        if not contains -- --model $argv
            set argv --model "gpt-5.6-sol[1m]" $argv
        end
        claude $argv
        set -l ret $status

        if set -q TMUX
            for v in $proxy_vars
                tmux set-environment -u $v
            end
        end
        return $ret
      '';

      # Hybrid team: native fable lead, GPT teammates. Pane teammates
      # inherit the tmux session environment rather than this process's,
      # so the proxy env goes only there — the lead itself talks straight
      # to Anthropic (native auth and caching; routing a Claude
      # subscription through the proxy is banned anyway). Outside tmux the
      # topology cannot hold (in-process teammates would spawn native), so
      # refuse to start.
      programs.fish.functions.claudem = ''
        if not set -q TMUX
            echo "claudem: hybrid teams need tmux — pane teammates carry the proxy env" >&2
            return 1
        end

        set -l pairs \
          ANTHROPIC_BASE_URL http://127.0.0.1:8317 \
          ANTHROPIC_AUTH_TOKEN ${localKey} \
          ANTHROPIC_SMALL_FAST_MODEL "gpt-5.6-luna[1m]" \
          ANTHROPIC_DEFAULT_OPUS_MODEL "gpt-5.6-sol[1m]" \
          ANTHROPIC_DEFAULT_SONNET_MODEL "gpt-5.6-terra[1m]" \
          ANTHROPIC_DEFAULT_HAIKU_MODEL "gpt-5.6-luna[1m]" \
          CLAUDE_CODE_ALWAYS_ENABLE_EFFORT 1 \
          ENABLE_TOOL_SEARCH false

        for i in (seq 1 2 (count $pairs))
            tmux set-environment $pairs[$i] $pairs[(math $i + 1)]
        end

        claude $argv
        set -l ret $status

        for i in (seq 1 2 (count $pairs))
            tmux set-environment -u $pairs[$i]
        end
        return $ret
      '';
      }
      (lib.mkIf pkgs.stdenv.isDarwin {
        launchd.agents.cliproxyapi = {
          enable = true;
          config = {
            ProgramArguments = [
              "${cliproxyapi}/bin/cli-proxy-api"
              "-config"
              "${configFile}"
            ];
            KeepAlive = true;
            RunAtLoad = true;
            StandardOutPath = "${config.home.homeDirectory}/Library/Logs/cliproxyapi.log";
            StandardErrorPath = "${config.home.homeDirectory}/Library/Logs/cliproxyapi.log";
          };
        };
      })
    ];
}
