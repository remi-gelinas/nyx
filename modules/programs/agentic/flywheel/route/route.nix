{
  flake.modules.homeManager.flywheel =
    { pkgs, ... }:
    let
      # Shadow-mode bead routing: a decision model sorts each bead into a
      # judgment tier, and code maps the tier to a pane model. Nothing is
      # enforced — every decision is appended to .beads/flywheel-route.jsonl
      # with an empty `label` for the operator to fill in, so the model can be
      # scored against real outcomes before routing ever steers a claim.
      #
      # The question asks about the work, not about models: tier names stay
      # stable when the fleet's models change, and option names describe
      # situations because decision models misroute on bare labels.
      questions = builtins.toJSON {
        tier = {
          type = "choice";
          instructions = "How much engineering judgment does implementing the work in `title`, `description`, and `acceptance_criteria` need?";
          criteria = {
            mechanical = "The exact edits are spelled out: renames, config values, docs, or a one-file fix with a known cause";
            standard = "Ordinary feature or bug work across a few files; the approach is clear but some code must be read and designed";
            subtle = "Concurrency, security, cryptography, data migration, an unclear root cause, an open design decision, or mistakes that fail silently";
          };
        };
      };

      tierModels = builtins.toJSON {
        mechanical = "openrouter/z-ai/glm-5.3-flash";
        standard = "openrouter/z-ai/glm-5.3";
        subtle = "openrouter/anthropic/claude-opus-5.5";
      };

      flywheel-route = pkgs.writeShellApplication {
        name = "flywheel-route";
        runtimeInputs = [
          pkgs.curl
          pkgs.jq
        ];
        text = ''
          model=''${FLYWHEEL_ROUTE_MODEL:-cloudflare/clef}
          # Below this confidence the tier is not trusted and the bead goes to
          # the strongest model: a wasted Opus turn is cheaper than a flash
          # model botching subtle work.
          min_conf=''${FLYWHEEL_ROUTE_MIN_CONFIDENCE:-0.5}
          key=$(cat "$HOME/.config/openrouter/key")

          if [ ! -d .beads ]; then
            echo "Not a flywheel repo (no .beads/ here)." >&2
            exit 1
          fi
          log=.beads/flywheel-route.jsonl

          # `-` routes beads from stdin (a br JSON array or JSONL export);
          # otherwise the ready frontier.
          if [ "''${1:-}" = - ]; then beads=$(cat); else beads=$(br ready --json); fi

          jq -c 'if type == "array" then .[] else . end' <<<"$beads" | while IFS= read -r bead; do
            req=$(jq -c --arg model "$model" --argjson questions '${questions}' '{
              model: $model,
              state: ({title, type: .issue_type, description, acceptance_criteria, design}
                | with_entries(select(.value != null and .value != ""))),
              questions: $questions
            }' <<<"$bead")
            if ! resp=$(curl -sf -m 30 https://openrouter.ai/api/alpha/decisions \
              -H "Authorization: Bearer $key" -H "Content-Type: application/json" -d "$req"); then
              echo "$(jq -r .id <<<"$bead"): decision request failed" >&2
              continue
            fi
            jq -c --argjson bead "$bead" --argjson tiers '${tierModels}' --argjson min "$min_conf" '
              .answers.tier as $t
              | (if $t.confidence >= $min then $t.choice else "subtle" end) as $route
              | {
                  ts: (now | todate),
                  bead: $bead.id,
                  title: $bead.title,
                  decision_model: .model,
                  provider: .provider,
                  tier: $t.choice,
                  confidence: $t.confidence,
                  probabilities: $t.probabilities,
                  route: $route,
                  pane_model: $tiers[$route],
                  label: null
                }' <<<"$resp" | tee -a "$log" | jq -r '[.bead, .tier, (.confidence * 100 | round | tostring) + "%", .pane_model, .title] | @tsv'
          done
        '';
      };
    in
    {
      home.packages = [ flywheel-route ];
    };
}
