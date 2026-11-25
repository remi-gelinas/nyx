{
  flake.modules.homeManager.flywheel =
    { pkgs, ... }:
    let
      # Shadow and live routing share the classifier and audit log.
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

      tierModels = builtins.toJSON (import ../_tier-models.nix);

      flywheel-route = pkgs.writeShellApplication {
        name = "flywheel-route";
        runtimeInputs = [
          pkgs.curl
          pkgs.jq
          pkgs.tmux
        ];
        text = ''
          model=''${FLYWHEEL_ROUTE_MODEL:-cloudflare/clef}
          # Below this confidence the tier is not trusted and the bead goes to
          # the strongest model: a wasted Opus turn is cheaper than a flash
          # model botching subtle work.
          min_conf=''${FLYWHEEL_ROUTE_MIN_CONFIDENCE:-0.5}
          if [ ! -d .beads ]; then
            echo "Not a flywheel repo (no .beads/ here)." >&2
            exit 1
          fi
          log=.beads/flywheel-route.jsonl
          live=.beads/flywheel-route-live.jsonl
          mode=''${1:-shadow}
          state='def state: {title, type: .issue_type, description, acceptance_criteria, design}
            | with_entries(select(.value != null and .value != ""));'
          case "$mode" in
            --scope)
              [[ $# == 3 && $2 =~ ^[a-zA-Z0-9_-]+$ && $3 =~ ^[a-zA-Z0-9_-]*$ ]] || { echo 'Usage: flywheel-route --scope SESSION BEAD_LABEL' >&2; exit 2; }
              scope="$live.scope.$2"
              if [[ -z $3 ]]; then rm -f "$scope"; exit; fi
              next=$(mktemp "$scope.XXXXXX")
              printf '%s\n' "$3" > "$next"
              mv "$next" "$scope"
              exit ;;
            --ready|--claim|--pane|--frontier)
              pane=''${FLYWHEEL_PANE_MODEL:-}
              tier=''${FLYWHEEL_TIER:-}
              if [[ $mode == --ready && $# == 2 ]]; then pane=$2; fi
              filter=()
              target=''${TMUX_PANE:-}
              if [[ $mode == --pane ]]; then
                [[ $# == 2 && $2 =~ ^%[0-9]+$ ]] || { echo 'Usage: flywheel-route --pane %PANE_ID' >&2; exit 2; }
                target=$2
                meta=$(tmux show-options -pqv -t "$target" @flywheel-route)
                [[ -n $meta ]] || { echo "No routing metadata for $target; cannot verify its queue" >&2; exit 1; }
                pane=$(jq -er '.model' <<<"$meta")
                tier=$(jq -er '.tier' <<<"$meta")
              elif [[ -n $target && $mode != --frontier ]]; then
                # A live pane may be moved from a restricted tier into its
                # model pool. Read the same restriction the supervisor sees.
                meta=$(tmux show-options -pqv -t "$target" @flywheel-route)
                if [[ -n $meta ]]; then tier=$(jq -er '.tier' <<<"$meta"); fi
              fi
              if [[ -n $target ]]; then
                session=$(tmux display-message -p -t "$target" '#{session_name}')
                [[ -n $session ]] || { echo 'Cannot resolve pane session for routing' >&2; exit 1; }
                if [[ -f $live.scope.$session ]]; then
                  read -r label < "$live.scope.$session"
                  filter=(--label "$label")
                fi
              fi
              ready=$(br ready --unassigned "''${filter[@]}" --json | jq --arg mode "$mode" --arg pane "$pane" --arg tier "$tier" --argjson tiers '${tierModels}' --slurpfile routes "$live" "$state"'
                INDEX($routes[]; .bead) as $index | map(select((.labels // [] | index("needs-human")) == null) | select(. as $b | $index[.id] as $r |
                  $r != null and ($mode == "--frontier" or ($tiers[$r.route] == $pane and ($tier == "" or $r.route == $tier))) and $r.state == ($b | state)) |
                  if $mode == "--frontier" then {id, route:$index[.id].route, model:$tiers[$index[.id].route]} else . end)')
              if [[ $mode == --frontier ]]; then echo "$ready"; exit; fi
              if [[ $mode == --pane ]]; then
                jq --argjson ready "$ready" --arg login "$(id -un)" '. + {ready:(if .role == "supervisor" or .actor == "" or .actor == $login then [] else $ready | map(.id) end)}' <<<"$meta"
                exit
              fi
              if [[ $mode == --ready ]]; then echo "$ready"; exit; fi
              [[ ''${FLYWHEEL_ROLE:-} != supervisor ]] || { echo 'Supervisor cannot claim beads' >&2; exit 1; }
              if [[ -n ''${TMUX_PANE:-} && ''${AGENT_NAME:-} == "$(id -un)" ]]; then
                echo "No swarm identity exported for $TMUX_PANE. Check ntm mapping --session $session before claiming." >&2
                exit 1
              fi
              id=$(jq -er 'first.id // empty' <<<"$ready") || { echo "No ready bead for $pane" >&2; exit 1; }
              exec br update --actor "''${AGENT_NAME:?missing pane identity}" "$id" --claim --json
              ;;
            --off) rm -f "$live"; exit ;;
            --live)
              touch "$live"
              next=$(mktemp "$live.XXXXXX")
              trap 'rm -f "$next"' EXIT
              ;;
            shadow|-) ;;
            *) echo 'Usage: flywheel-route [ - | --live | --frontier | --pane %ID | --ready [MODEL] | --claim | --scope SESSION LABEL | --off ]' >&2; exit 2 ;;
          esac
          key=$(cat "$HOME/.config/openrouter/key")

          # `-` routes beads from stdin (a br JSON array or JSONL export);
          # otherwise the ready frontier.
          if [ "''${1:-}" = - ]; then beads=$(cat); else beads=$(br ready --json); fi

          rows=$(jq -c 'if type == "array" then .[] else . end' <<<"$beads")
          failed=0
          while IFS= read -r bead; do
            [[ -n $bead ]] || continue
            req=$(jq -c --arg model "$model" --argjson questions '${questions}' "$state"'{
              model: $model,
              state: state,
              questions: $questions
            }' <<<"$bead")
            if [[ $mode == --live ]]; then
              cached=$(jq -c --argjson b "$bead" --argjson req "$req" --argjson min "$min_conf" --argjson tiers '${tierModels}' '
                select(.bead == $b.id and .state == $req.state and .requested_model == $req.model and .min_confidence == $min)
                | .pane_model = $tiers[.route]' "$live")
              if [[ -n $cached ]]; then echo "$cached" >> "$next"; continue; fi
            fi
            if ! resp=$(curl -sf -m 30 https://openrouter.ai/api/alpha/decisions \
              -H "Authorization: Bearer $key" -H "Content-Type: application/json" -d "$req"); then
              echo "$(jq -r .id <<<"$bead"): decision request failed" >&2
              failed=1
              continue
            fi
            if ! row=$(jq -ce --argjson bead "$bead" --argjson req "$req" --argjson tiers '${tierModels}' --argjson min "$min_conf" '
              .answers.tier as $t
              | select(($tiers | has($t.choice)) and ($t.confidence | type == "number" and . >= 0 and . <= 1))
              | (if $t.confidence >= $min then $t.choice else "subtle" end) as $route
              | {
                  ts: (now | todate),
                  bead: $bead.id,
                  title: $bead.title,
                  decision_model: .model,
                  requested_model: $req.model,
                  state: $req.state,
                  min_confidence: $min,
                  provider: .provider,
                  tier: $t.choice,
                  confidence: $t.confidence,
                  probabilities: $t.probabilities,
                  route: $route,
                  pane_model: $tiers[$route],
                  label: null
                }' <<<"$resp"); then
              echo "$(jq -r .id <<<"$bead"): invalid decision" >&2
              failed=1
              continue
            fi
            echo "$row" | tee -a "$log" | jq -r '[.bead, .tier, (.confidence * 100 | round | tostring) + "%", .pane_model, .title] | @tsv'
            if [[ $mode == --live ]]; then echo "$row" >> "$next"; fi
          done <<<"$rows"
          if [[ $mode == --live ]]; then mv "$next" "$live"; fi
          exit "$failed"
        '';
      };
    in
    {
      home.packages = [ flywheel-route ];
    };
}
