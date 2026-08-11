{
  flake.modules.homeManager.flywheel =
    { config, pkgs, ... }:
    let
      # Same paths agent-mail.nix pins; recomputed here so flywheel-init is
      # self-sufficient and works even from a stale pre-switch shell that never
      # sourced the exports.
      storageRoot = "${config.home.homeDirectory}/.mcp_agent_mail_git_mailbox_repo";
      databaseUrl = "sqlite+aiosqlite:///${storageRoot}/storage.sqlite3";
      mcpUrl = "http://127.0.0.1:8765/mcp/";

      # The lease guard's hook reads AGENT_NAME strictly from the commit env
      # (exit 2 without it), but ntm assigns per-pane identity in its own
      # table and never exports it. Identity therefore has to be derived when
      # the AGENT PROCESS starts — the claude/codex launch wrappers call this
      # and every git commit inherits the env. Fronting the installed hook
      # with a wrapper instead is unsalvageable: the guard's chain-runner
      # unconditionally executes `pre-commit.orig`, so the first reinstall
      # (agents can call install_precommit_guard at any time) backs the
      # wrapper up into the chain and wrapper→chain-runner→.orig recurses —
      # every passing commit spawned an unbounded process tree that starved
      # the machine and the agent-mail DB. The brief poll covers the race
      # with ntm registering the pane just after spawn; outside tmux it
      # returns immediately, and the interactive-shell fallback (username)
      # covers human commits, which then only block on another agent's lease.
      # The poll is capped at 5s because `ntm mapping` cannot distinguish a
      # manual tmux session from a not-yet-registered swarm pane (both report
      # zero agents, exit 0) — a manual-tmux claude launch pays at most that.
      agentEnvFunction = ''
        if set -q TMUX_PANE; and command -q ntm; and command -q tmux
          set -l session (tmux display-message -p '#{session_name}' 2>/dev/null)
          if test -n "$session"
            for _ in (seq 10)
              set -l name (ntm mapping --session $session 2>/dev/null | ${pkgs.gawk}/bin/awk -v p=$TMUX_PANE '$3==p{print $1; exit}')
              if test -n "$name"
                set -gx AGENT_NAME $name
                set -q BR_ACTOR; or set -gx BR_ACTOR $name
                return 0
              end
              sleep 0.5
            end
          end
        end
      '';

      # Harvested from post_compact_reminder's installer (the script it embeds
      # in render_hook_script, default TEMPLATE_DEFAULT message) rather than
      # running the installer: shebang comes from writeShellScript, jq is
      # pinned to the store path. Fires on SessionStart source="compact" and
      # prints the reread-AGENTS.md reminder into the fresh context.
      postCompactReminder = pkgs.writeShellScript "claude-post-compact-reminder" ''
        set -e
        MESSAGE='🚨 IMPORTANT: Context was just compacted. STOP. You MUST:
        1. Read AGENTS.md NOW
        2. Confirm by briefly stating what key rules/conventions you found

        Do not proceed with any task until you have read the file and confirmed what you learned.'
        INPUT=$(cat)
        SOURCE=$(printf '%s' "$INPUT" | ${pkgs.jq}/bin/jq -r '.source // empty' 2>/dev/null || true)
        if [ "$SOURCE" = "compact" ]; then
          printf '%s\n' "$MESSAGE"
        fi
        exit 0
      '';

      # Codex is plain nixpkgs (MIT-clean vendor tooling), pulled from
      # nixpkgs-master for the current release. ntm can then spawn both claude
      # and codex panes. Auth is a one-time interactive `codex login` by the
      # user; this only delivers the binary.

      brSources = import ./br/_sources.nix { inherit (pkgs) fetchFromGitHub; };
      bvSources = import ./bv/_sources.nix { inherit (pkgs) fetchFromGitHub; };
      ntmSources = import ./ntm/_sources.nix { inherit (pkgs) fetchFromGitHub; };

      # bv and ntm ship SKILL.md at their repo root rather than under
      # .claude/skills/, so each gets a minimal one-file skill dir instead of
      # pointing the skill at the whole repo checkout.
      ntmSkill = pkgs.runCommand "ntm-skill" { } ''
        mkdir -p $out
        cp ${ntmSources.ntm.src}/SKILL.md $out/SKILL.md
      '';

      # br ships its skill in-tree, but two of its habits contradict the
      # operating rules on repos with non-flywheel contributors: commit
      # examples embed the bead id in the message ("feat: X (<id>)"), and the
      # workflow commits `.beads/` into the repo — here the board is
      # machine-local and flywheel-init excludes it via .git/info/exclude.
      # Strip the id and the `git add .beads/` steps from the examples;
      # everything else is taken as-is, references/ included.
      brSkill = pkgs.runCommand "br-skill" { } ''
        cp -r ${brSources.br.src}/.claude/skills/br $out
        chmod +w $out $out/SKILL.md
        sed -i \
          -e 's/git commit -m "feat: X (<id>)"/git commit -m "feat: X"/g' \
          -e 's|git add .beads/ && git commit -m "Update issues"|: # .beads/ is git-excluded on this machine; never commit it|g' \
          -e 's|you must `git add .beads/ && git commit`|`.beads/` is git-excluded here; never commit it|' \
          -e 's|git add .beads/ && ||g' \
          $out/SKILL.md
      '';

      # Same treatment for bv, plus a text fix: bv's own "Agent Workflow
      # Pattern" (not the section below it that's explicitly labeled legacy)
      # tells the agent to run `bd claim`/`bd close`, but `bd` is the old Go
      # binary — br is current. Swapped for br's actual equivalents, keyed on
      # the actor var flywheel-init tells every pane to export.
      bvSkill = pkgs.runCommand "bv-skill" { } ''
        mkdir -p $out
        sed \
          -e 's/^bd claim "\$NEXT_TASK"$/br update --actor "$BR_ACTOR" "$NEXT_TASK" --status in_progress --claim/' \
          -e 's/^bd close "\$NEXT_TASK"$/br close --actor "$BR_ACTOR" "$NEXT_TASK" --reason "Completed"/' \
          ${bvSources.bv.src}/SKILL.md > $out/SKILL.md
      '';

      # Global operator context = the methodology rules plus the repo-agnostic
      # tool reference, delivered to both harnesses' user-level instruction
      # files. Nothing here is committed into a project.
      globalContext = builtins.readFile ./context/flywheel.md + "\n" + builtins.readFile ./context/tool-reference.md;
    in
    {
      home.packages = [ pkgs.master.codex ];

      # Enables agent-mail's per-agent git-identity features. The Rust guard
      # itself no longer gates on this (it is active unless
      # FILE_RESERVATIONS_ENFORCEMENT_ENABLED is explicitly false), but the
      # server's identity features still read it, and it is a constant —
      # global session env, not a per-pane export like BR_ACTOR/AGENT_NAME.
      # (STORAGE_ROOT and DATABASE_URL are set alongside in agent-mail.nix.)
      # PROJECT_IDENTITY_MODE stays at its default `dir` so the project slug
      # remains slugify(path) and the guard and the server compute the same
      # slug.
      home.sessionVariables.GIT_IDENTITY_ENABLED = "1";

      programs.claude-code.skills = {
        br = brSkill;
        bv = bvSkill;
        ntm = ntmSkill;
      };

      # Per-repo mechanical bootstrap only — no committed context. The tool
      # blurbs and methodology live in global operator context (see below), so
      # a solo adopter never writes a flywheel-flavored AGENTS.md into a shared
      # repo. Steps, in order: refuse a repo that already has a bd (Dolt) board
      # (br and bd both claim `.beads/`); init the br board; register the repo
      # via the running service's ensure_project tool; install the advisory
      # pre-commit lease guard. The ensure_project call matters even though any
      # tool call auto-creates the DB row: only ensure_project writes the
      # archive's project.json, and without it the guard hook cannot attribute
      # the archive to this repo and silently skips enforcement. All local
      # state — `.beads/` is excluded via .git/info/exclude, the guard in
      # `.git/hooks/`. `guard install` takes PROJECT and REPO positionally
      # (both the absolute repo path).
      programs.fish.functions.flywheel-init = ''
        set -lx STORAGE_ROOT ${storageRoot}
        set -lx DATABASE_URL ${databaseUrl}
        set -lx GIT_IDENTITY_ENABLED 1
        if test -d .beads/embeddeddolt
          echo "This repo has a bd (Dolt) board at .beads/; br would collide. Migrate it (bd export | br import) or run the flywheel on a repo without one. Aborting."
          return 1
        end
        if not test -d .beads
          br init
        end
        # The board is machine-local swarm state: every agent shares this one
        # checkout, and the repo's non-flywheel contributors should never see
        # bead artifacts. .git/info/exclude keeps it out of git without
        # touching the shared .gitignore.
        if test -d .git; and not grep -qxF '.beads/' .git/info/exclude 2>/dev/null
          echo '.beads/' >> .git/info/exclude
        end
        set -l resp (curl -s -m 10 -X POST ${mcpUrl} -H 'Content-Type: application/json' -H 'Accept: application/json, text/event-stream' -d '{"jsonrpc":"2.0","id":1,"method":"tools/call","params":{"name":"ensure_project","arguments":{"human_key":"'$PWD'"}}}')
        if test -z "$resp"; or string match -q '*"isError":true*' -- "$resp"
          echo "ensure_project failed — is the mcp-agent-mail service running? The lease guard cannot attribute this repo's archive until it succeeds. Aborting."
          return 1
        end
        # Purge artifacts of the retired hook-fronting approach BEFORE the
        # install: a leftover wrapper at pre-commit would be backed up into
        # pre-commit.orig, which the chain-runner executes on every commit —
        # and a wrapper or second chain-runner reachable from .orig recurses
        # (wrapper -> chain-runner -> .orig -> wrapper ...), spawning an
        # unbounded process tree on every passing commit. Only files that are
        # ours are touched; a genuine user hook backed up in .orig survives.
        for f in .git/hooks/pre-commit .git/hooks/pre-commit.orig .git/hooks/pre-commit.flywheel-inner .git/hooks/pre-push.orig .git/hooks/pre-push.flywheel-inner
          if test -f $f; and grep -q 'flywheel-identity-wrapper' $f
            rm $f
          else if test -f $f; and string match -q '*.orig' -- $f; and grep -q 'mcp-agent-mail chain-runner' $f
            rm $f
          else if test -f $f; and string match -q '*.flywheel-inner' -- $f
            rm $f
          end
        end
        am guard install $PWD $PWD
        echo "Board, agent-mail project, and lease guard ready. Agent identity is exported at claude/codex launch; the stock guard hooks run untouched."
      '';

      programs.fish.functions.flywheel-agent-env = agentEnvFunction;

      # OpenRouter gateway switch, called by the claude launch wrapper with
      # the model about to be requested. OpenRouter slugs carry a slash
      # (moonshotai/kimi-k2, z-ai/glm-4.7, anthropic/claude-sonnet-5 for
      # Claude on OpenRouter billing); plain Anthropic ids don't, and leave
      # the Enterprise session untouched. OpenRouter's Anthropic-native
      # endpoint means claude runs unmodified — this only points it there
      # and presents the key, per-process. Fails loudly when the key file is
      # missing: launching a pane on the wrong billing silently is worse
      # than not launching it.
      programs.fish.functions.flywheel-openrouter-env = ''
        if not string match -q '*/*' -- $argv[1]
          return 0
        end
        set -l keyfile ~/.config/openrouter/key
        if not test -r $keyfile
          echo "flywheel: model $argv[1] routes via OpenRouter, but $keyfile is missing (create it with the API key as its only line, chmod 600)." >&2
          return 1
        end
        set -gx ANTHROPIC_BASE_URL https://openrouter.ai/api
        set -gx ANTHROPIC_AUTH_TOKEN (head -n1 $keyfile | string trim)
        set -e ANTHROPIC_API_KEY
      '';

      # codex has no launch wrapper of its own (claude's lives in
      # claude-code.nix and calls the same helper); without this a codex
      # pane's commits carry no AGENT_NAME and the guard refuses them.
      programs.fish.functions.codex = ''
        flywheel-agent-env
        command codex $argv
      '';

      # Human fallback: the guard hook hard-refuses any commit without
      # AGENT_NAME. Interactive shells get the username; agent panes override
      # it at claude/codex launch. A human holds no leases under this name,
      # so their commits pass unless they touch a file an agent has reserved
      # — which is exactly when they should be stopped too.
      programs.fish.interactiveShellInit = ''
        set -q AGENT_NAME; or set -gx AGENT_NAME (id -un)
      '';

      # The bd allows vanished with the beads module; these are the flywheel
      # tool CLIs agents drive. Concatenates with the claude-code core list.
      # ntm and cass are kept broad deliberately (single-user machine,
      # experiment friction outweighs the narrower-allowlist benefit) per
      # review. Agents drive agent-mail primarily through the MCP server, but
      # `am` (the Rust robot CLI) is allowed too: it is agent-oriented by
      # design and the server's own error messages direct callers to `am`
      # commands.
      programs.claude-code.settings.permissions.allow = map (p: "Bash(${p}:*)") [
        "br"
        "bv"
        "ntm"
        "ubs"
        "dcg"
        "cass"
        "am"
      ];

      # Every pane shows its swarm identity at a glance: the statusline
      # command inherits the claude process env, and the launch wrapper put
      # AGENT_NAME there. ntm's own pane titles are a fixed session__cc_N
      # convention, so this is the surface that can carry the agent-mail
      # name. Outside a swarm it degrades to the model name alone.
      programs.claude-code.settings.statusLine = {
        type = "command";
        command = "${pkgs.writeShellScript "flywheel-statusline" ''
          input=$(cat)
          model=$(printf '%s' "$input" | ${pkgs.jq}/bin/jq -r '.model.display_name // .model.id // ""' 2>/dev/null)
          if [ -n "$AGENT_NAME" ] && [ "$AGENT_NAME" != "$(id -un)" ]; then
            printf '⛭ %s · %s' "$AGENT_NAME" "$model"
          else
            printf '%s' "$model"
          fi
        ''}";
      };

      programs.claude-code.settings.hooks.SessionStart = [
        {
          matcher = "compact";
          hooks = [
            {
              type = "command";
              command = "${postCompactReminder}";
            }
          ];
        }
      ];

      programs.claude-code.settings.skipDangerousModePermissionPrompt = true;

      # Global operating rules + tool reference for both harnesses. Claude Code
      # renders context into ~/.claude/CLAUDE.md; Codex reads ~/.codex/AGENTS.md.
      # Both are user-level and machine-local — a solo adopter's flywheel
      # knowledge reaches their own agents on every repo without committing
      # anything, so shared repos and their other contributors are untouched.
      programs.claude-code.context = globalContext;
      home.file.".codex/AGENTS.md".text = globalContext;
      home.file."${config.programs.claude-code.configDir}/CLAUDE.md".force = true;
    };
}
