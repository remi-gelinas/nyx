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
      # the AGENT PROCESS starts — the opencode launch wrapper calls this
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
      # zero agents, exit 0) — a manual-tmux opencode launch pays at most that.
      agentEnvFunction = ''
        if set -q TMUX_PANE; and command -q ntm; and command -q tmux
          set -l session (tmux display-message -p '#{session_name}' 2>/dev/null)
          if test -n "$session"
            for i in (seq 10)
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

      # Commit messages describe the change for the repository's history, never
      # the process that produced it — but that rule is prompt-level and decays
      # with context, and the repo's non-flywheel contributors are the ones who
      # inherit the leak. This commit-msg hook is the mechanical backstop. It
      # matches only identifiers that never legitimately appear in history:
      # bead ids, the committing agent's own name, AI bylines, review
      # bookkeeping. Process *vocabulary* is deliberately not matched — this
      # repo's own commits are about the flywheel ("flywheel: attach epic
      # children with parent-child"), and banning the words would reject them.
      #
      # commit-msg, not pre-commit: pre-commit hooks are not passed the
      # message. That also keeps this clear of agent-mail's lease guard, which
      # only ever writes pre-commit and pre-push — no chaining, no wrapper, and
      # none of the recursion the guard's chain-runner invites.
      # Plain sh with PATH tools rather than pinned store paths: this file
      # persists on disk between switches and must not break when a store
      # path is garbage-collected.
      commitMsgHook = pkgs.writeTextFile {
        name = "flywheel-commit-msg";
        executable = true;
        text = ''
          #!/bin/sh
          # flywheel-commit-msg-guard
          # Cut the `git commit -v` scissors block, then the comment lines, so
          # the diff and git's own template never trip a pattern.
          msg=$(sed '/^# .*>8/,$d' "$1" | grep -v '^#')

          fail() {
            echo "commit-msg: $1" >&2
            echo "  Commit messages describe the change, not the process behind it." >&2
            echo "  Bead ids belong in \`br close --reason\`, mail thread_ids, and reservation reasons." >&2
            echo "  Rewrite the message, or bypass with: git commit --no-verify" >&2
            exit 1
          }

          printf '%s' "$msg" | grep -qiE '(^|[^a-z0-9])(br|bd)-[0-9]+' &&
            fail "bead id in the message"
          printf '%s' "$msg" | grep -qiE 'co-authored-by:.*(claude|anthropic)|generated with.*claude' &&
            fail "AI byline in the message"
          printf '%s' "$msg" | grep -qiE 'review round|self-review|fresh-eyes review|round [0-9]+ of review' &&
            fail "review bookkeeping in the message"

          # Swarm identities only. Interactive shells set AGENT_NAME to the
          # username, and a human's own name is not a process leak.
          if [ -n "$AGENT_NAME" ] && [ "$AGENT_NAME" != "$(id -un)" ]; then
            printf '%s' "$msg" | grep -qiF "$AGENT_NAME" &&
              fail "agent name '$AGENT_NAME' in the message"
          fi

          exit 0
        '';
      };

      # The flywheel loop, pane-identity injection, post-compact reminder, and
      # dcg bridge all live in opencode's plugin now (it reads the same
      # .beads/flywheel-pause sentinels flywheel-pause/-resume drop). opencode
      # is the only harness.

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
      # tool reference, delivered to opencode's user-level AGENTS.md. Nothing
      # here is committed into a project.
      globalContext = builtins.readFile ./context/flywheel.md + "\n" + builtins.readFile ./context/tool-reference.md;
    in
    {
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

      programs.opencode = {
        skills = {
          br = brSkill;
          bv = bvSkill;
          ntm = ntmSkill;
        };
        settings = {
          # Swarm autonomy comes from --auto in ntm's seeded oc template
          # (auto-approve everything not explicitly denied). Explicit deny
          # policies still apply under --auto, and dcg (bridged by the plugin
          # below) stays the destructive-command backstop. The interactive
          # allowlist in opencode.nix is untouched.
          #
          # The plugin carries the stop-frontier loop, pane identity
          # injection, post-compact reminder, dcg bridge, and liveness
          # sentinel. The dir must contain the entry module — opencode skips
          # single-file plugin paths.
          plugins = [ "${./_opencode-plugin}" ];
        };
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
        # Copied, not symlinked: the hook has to survive a store GC. Refuses to
        # clobber a genuine user commit-msg hook — ours is identified by the
        # marker comment, so reinstalling over our own is fine.
        if test -f .git/hooks/commit-msg; and not grep -q 'flywheel-commit-msg-guard' .git/hooks/commit-msg
          echo "Left the existing .git/hooks/commit-msg alone; the message guard is not installed. Chain it yourself or move it aside."
        else
          cp -f ${commitMsgHook} .git/hooks/commit-msg
          chmod +x .git/hooks/commit-msg
        end
        echo "Board, agent-mail project, lease guard, and commit-message guard ready. Agent identity is exported at opencode launch; the stock guard hooks run untouched."
      '';

      programs.fish.functions.flywheel-agent-env = agentEnvFunction;

      # Operator switch for the work loop (opencode's plugin reads these
      # sentinels): paused, agents finish their current turn and are allowed
      # to stop even with a non-empty frontier. Run from the repo root. No
      # args = the whole swarm; agent names = just those agents (everyone
      # else keeps looping).
      programs.fish.functions.flywheel-pause = ''
        if not test -d .beads
          echo "Not a flywheel repo (no .beads/ here)."
          return 1
        end
        if test (count $argv) -eq 0
          touch .beads/flywheel-pause
          echo "Paused (all agents): they may stop after their current turn. flywheel-resume to lift."
        else
          for n in $argv
            touch .beads/flywheel-pause-$n
          end
          echo "Paused: $argv. Others keep looping. flywheel-resume $argv to lift."
        end
      '';
      programs.fish.functions.flywheel-resume = ''
        if test (count $argv) -gt 0
          for n in $argv
            rm -f .beads/flywheel-pause-$n
          end
          echo "Resumed: $argv. Nudge their panes (ntm --robot-send) to restart them."
          return 0
        end
        set -l sentinels .beads/flywheel-pause*
        if test (count $sentinels) -eq 0
          echo "Not paused."
          return 0
        end
        rm $sentinels
        echo "Resumed: agents are held on the loop again. Nudge idle panes (ntm --robot-send) to restart them."
      '';

      # opencode's launch wrapper exports the pane's ntm identity before
      # launch. Panes also run --standalone (seeded into ntm's oc template):
      # the v2 shared daemon owns tool execution, so an attached pane's shell
      # and git commits would inherit the daemon's env — one AGENT_NAME for
      # every pane — instead of its own.
      #
      # --fw-model <id> is a sentinel the oc template adds for --oc=N:model:
      # opencode's v2 TUI has no --model flag, so the model rides an env var
      # the plugin reads (FLYWHEEL_OC_MODEL → session.switchModel). Strip it
      # here — opencode would reject the unknown flag — and export it so the
      # standalone server and its plugin inherit it, same path as AGENT_NAME.
      programs.fish.functions.opencode = ''
        flywheel-agent-env
        set -l args
        set -l i 1
        while test $i -le (count $argv)
          if test "$argv[$i]" = --fw-model
            set -gx FLYWHEEL_OC_MODEL $argv[(math $i + 1)]
            set i (math $i + 2)
          else
            set -a args $argv[$i]
            set i (math $i + 1)
          end
        end
        command opencode $args
      '';

      # Human fallback: the guard hook hard-refuses any commit without
      # AGENT_NAME. Interactive shells get the username; agent panes override
      # it at opencode launch. A human holds no leases under this name, so
      # their commits pass unless they touch a file an agent has reserved —
      # which is exactly when they should be stopped too.
      programs.fish.interactiveShellInit = ''
        set -q AGENT_NAME; or set -gx AGENT_NAME (id -un)
      '';

      # Global operating rules + tool reference, delivered to opencode's
      # user-level AGENTS.md (via programs.opencode.context → the
      # ~/.config/opencode/AGENTS.md the module writes). Machine-local — a solo
      # adopter's flywheel knowledge reaches their own agents on every repo
      # without committing anything, so shared repos and their other
      # contributors are untouched. (opencode allows bash by default, so the
      # br/bv/ntm/ubs/dcg/cass/am CLIs need no explicit allowlist.)
      programs.opencode.context = globalContext;
    };
}
