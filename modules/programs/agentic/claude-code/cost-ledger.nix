{
  flake.modules.homeManager.claude-code-cost-ledger =
    { pkgs, lib, ... }:
    let
      jq = lib.getExe pkgs.jq;
      # TaskCompleted fires in the session that marks the task done; its
      # transcript_path is that session's transcript. SubagentStop carries
      # the subagent's own transcript in agent_transcript_path. Records hold
      # per-model cumulative usage plus the delta since the previous ledger
      # entry for the same transcript — the token cost of the completed task
      # or subagent turn. Keying prev-lookup on the transcript also keeps
      # re-stopped (continued) subagents from double-counting. Always exit 0:
      # a failed record must never block completion.
      record = pkgs.writeShellScript "claude-cost-record" ''
        payload=$(cat)
        ledger="$HOME/.claude/cost-ledger.jsonl"
        {
          tp=$(printf '%s' "$payload" | ${jq} -r '.agent_transcript_path // .transcript_path // empty')
          [ -n "$tp" ] && [ -f "$tp" ] || exit 0

          # Usage grouped by responding model, so mixed-tier sessions (and
          # proxy-routed GPT tiers with 5x price spreads) stay attributable.
          cumulative=$(${jq} -cs '
            [ .[] | select(.message.usage) | { model: (.message.model // "unknown"), u: .message.usage } ]
            | group_by(.model)
            | map({ key: .[0].model, value: {
                input: (map(.u.input_tokens // 0) | add),
                output: (map(.u.output_tokens // 0) | add),
                cache_read: (map(.u.cache_read_input_tokens // 0) | add),
                cache_creation: (map(.u.cache_creation_input_tokens // 0) | add) } })
            | from_entries' "$tp")

          prev='{}'
          if [ -f "$ledger" ]; then
            last=$(${jq} -c --arg tp "$tp" 'select(.transcript == $tp) | .cumulative' "$ledger" | tail -1)
            [ -n "$last" ] && prev=$last
          fi

          printf '%s' "$payload" | ${jq} -c \
            --arg ts "$(date -u +%FT%TZ)" \
            --arg tp "$tp" \
            --argjson cur "$cumulative" \
            --argjson prev "$prev" \
            '{ ts: $ts,
               kind: .hook_event_name,
               session_id: .session_id,
               transcript: $tp,
               cwd: .cwd,
               task_id: (.task_id // null),
               task_subject: (.task_subject // null),
               agent_id: (.agent_id // null),
               agent_type: (.agent_type // null),
               cumulative: $cur,
               delta: ($cur | to_entries | map(.key as $m | .value = (.value | with_entries(.value -= ((($prev[$m] // {})[.key]) // 0)))) | from_entries) }' >> "$ledger"
        } 2>/dev/null || true
        exit 0
      '';
      recordHook = [
        {
          hooks = [
            {
              type = "command";
              command = "${record}";
            }
          ];
        }
      ];
      # API-list rates in USD per million tokens, keyed by the model ids
      # that appear in ledger delta keys. cache_read ~10% of input on both
      # providers; cache_creation 1.25x input (Anthropic only; the proxy
      # reports 0 for GPT). Bump when prices change.
      rateCard = {
        "gpt-5.6-sol" = {
          input = 5.0;
          output = 30.0;
          cache_read = 0.5;
          cache_creation = 0.0;
        };
        "gpt-5.6-terra" = {
          input = 2.5;
          output = 15.0;
          cache_read = 0.25;
          cache_creation = 0.0;
        };
        "gpt-5.6-luna" = {
          input = 1.0;
          output = 6.0;
          cache_read = 0.1;
          cache_creation = 0.0;
        };
        "claude-fable-5" = {
          input = 10.0;
          output = 50.0;
          cache_read = 1.0;
          cache_creation = 12.5;
        };
        "claude-opus-4-8" = {
          input = 5.0;
          output = 25.0;
          cache_read = 0.5;
          cache_creation = 6.25;
        };
        "claude-sonnet-5" = {
          input = 3.0;
          output = 15.0;
          cache_read = 0.3;
          cache_creation = 3.75;
        };
        "claude-sonnet-4-6" = {
          input = 3.0;
          output = 15.0;
          cache_read = 0.3;
          cache_creation = 3.75;
        };
        "claude-haiku-4-5-20251001" = {
          input = 1.0;
          output = 5.0;
          cache_read = 0.1;
          cache_creation = 1.25;
        };
      };
    in
    {
      home.file.".claude/cost-rates.json".text = builtins.toJSON {
        comment = "USD per million tokens, API-list approximations; actual billing may be subscription quota";
        rates = rateCard;
      };

      programs.claude-code.settings.hooks = {
        TaskCompleted = recordHook;
        SubagentStop = recordHook;
        # Closing sweep per session: leads never complete tasks, so without
        # this the orchestrator's own (frontier-priced) usage is unledgered.
        SessionEnd = recordHook;
      };
    };
}
