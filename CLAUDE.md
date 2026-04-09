# linear-sdlc — notes for Claude

This repo is a Claude Code **skills pack** that implements a Linear-driven SDLC workflow. Read `README.md` for the user-facing description; this file is for agents working on the repo itself.

## Layout

```
linear-sdlc/
├── setup                              # bash installer (idempotent, gstack-style)
├── VERSION                            # plain semver string, fetched from GitHub raw by the update check
├── bin/
│   ├── lsdlc-slug                     # derive project slug + branch from git
│   ├── lsdlc-config                   # read/write ~/.linear-sdlc/config.json
│   ├── lsdlc-timeline-log             # append skill events to timeline.jsonl
│   ├── lsdlc-learnings-log            # append learnings to learnings.jsonl
│   ├── lsdlc-learnings-search         # query learnings with confidence decay
│   ├── lsdlc-wiki                     # LLM wiki plumbing CLI (init, log-append, index-upsert,
│   │                                  #   lint, search, secret-scan, migrate, ingest-source,
│   │                                  #   sync-linear, linear-map, qmd-setup, qmd-refresh)
│   ├── lsdlc-wiki-ingest              # deprecated shim → /wiki ingest
│   ├── lsdlc-wiki-lint                # deprecated shim → lsdlc-wiki lint
│   ├── lsdlc-update-check             # silent release-check helper called by the shared preamble
│   ├── lsdlc-session-update           # team-mode background worker (SessionStart hook)
│   ├── lsdlc-settings-hook            # idempotent add/remove of SessionStart hook in ~/.claude/settings.json
│   └── lsdlc-linear                   # Linear GraphQL helper (Node, zero deps). Includes
│                                      #   document-upsert for one-way wiki → Linear sync
│                                      #   and update-issue for /update-tickets.
├── skills/
│   ├── brainstorm/SKILL.md            # /brainstorm — feature planning (reads wiki prior art)
│   ├── create-tickets/SKILL.md        # /create-tickets — spec → Linear issues
│   ├── update-tickets/SKILL.md        # /update-tickets — refresh stale Linear issue descriptions to the template
│   ├── next/SKILL.md                  # /next — pick next ticket
│   ├── implement/
│   │   ├── SKILL.md                   # /implement — full ticket lifecycle + auto wiki ingest
│   │   └── specialists/               # checklists consumed by parallel sub-agents
│   │       ├── testing.md
│   │       ├── security.md
│   │       ├── performance.md
│   │       └── code-quality.md
│   ├── debug/SKILL.md                 # /debug — bug investigation + auto incident write
│   ├── wiki/SKILL.md                  # /wiki — init/ingest/query/lint/sync/sync-linear/...
│   ├── checkpoint/SKILL.md            # /checkpoint — save/resume state
│   ├── health/SKILL.md                # /health — code quality dashboard (+ wiki row)
│   └── upgrade/SKILL.md               # /upgrade — autoupdate dialog + git upgrade
├── references/
│   ├── preamble.sh                    # shared bash preamble + _WIKI resolution
│   ├── wiki-schema-template.md        # CLAUDE.md template scaffolded into <wiki>/CLAUDE.md
│   ├── ask-user-format.md             # AskUserQuestion template
│   ├── completion-status.md           # STATUS protocol
│   └── verification-gate.md           # evidence-first claim pattern
├── templates/
│   └── spec-template.md               # written by /brainstorm, read by /create-tickets
├── README.md                          # user-facing
├── ETHOS.md                           # design principles
├── CHANGELOG.md                       # release notes
└── LICENSE
```

## Distribution model

linear-sdlc is **not** a Claude Code plugin. There is no `.claude-plugin/`, no `plugin.json`, no `marketplace.json`, no embedded MCP server. v1 was a plugin; v2 reverted to the gstack-style skills pack pattern. See `CHANGELOG.md` for the rationale.

Users install by:

```bash
git clone git@github.com:douglasswm/linear-sdlc.git ~/.claude/skills/linear-sdlc
cd ~/.claude/skills/linear-sdlc
./setup
```

`./setup` is idempotent — re-running it is safe and respects existing config.

## How `setup` wires things up

1. **Skill symlinks.** For each `skills/<dir>/SKILL.md`, setup creates `~/.claude/skills/<dir>/` (a real directory) containing a `SKILL.md` symlink pointing back into this repo. For `/implement`, it also symlinks the `specialists/` subdirectory so the parallel sub-agent checklists resolve relative to the linked SKILL.md. With `--prefix`, names become `~/.claude/skills/linear-sdlc-<dir>/`.
2. **`bin/` on PATH.** For each script in `bin/`, setup symlinks it into `~/.local/bin/`. Skills invoke them as bare commands (e.g., `lsdlc-linear get-issue VER-42`). If `~/.local/bin` is not on the user's `PATH`, setup warns once but does not mutate shell rc files.
3. **API key.** Setup prompts for the Linear API key and writes it to `~/.linear-sdlc/env` with mode `0600`. The shared preamble (`references/preamble.sh`) parses this file in pure shell to load `LINEAR_API_KEY` — it never `.`-sources the file, because that would be an RCE surface if another process tampered with it. It also refuses to read the file if it's group/other-writable or not owned by the current user.
4. **Team ID.** Setup prompts for the Linear team identifier and saves it via `lsdlc-config set linear_team_id <VALUE>`. The field accepts either a short team key (e.g., `VER`) or a team UUID (e.g., `07877f05-4f32-42b4-a2df-9e1764316652`). `bin/lsdlc-linear` auto-detects the format via a UUID regex and builds the appropriate GraphQL filter (`team: { id: ... }` vs `team: { key: ... }`). If you add a new code path that filters by team, use the `teamFilter()` / `teamMatches()` helpers in `lsdlc-linear` — don't hardcode `key`.
5. **Source dir.** Setup persists the absolute repo path via `lsdlc-config set source_dir "$SOURCE_DIR"` so the preamble's path resolver has a fallback if `readlink` fails.
6. **MCP prompt (informational only).** Setup prints instructions for installing Linear's first-party HTTP MCP (`claude mcp add --transport http linear https://mcp.linear.app/mcp`) but never installs it. The skills don't depend on it.
7. **Team mode (opt-in).** `./setup --team` sets `team_mode: true` + `auto_upgrade: true` in `config.json` and calls `bin/lsdlc-settings-hook add "$HOME/.local/bin/lsdlc-session-update"` to register the background auto-updater as a `SessionStart` hook in `~/.claude/settings.json`. `./setup --no-team` unsets the flags and strips the hook (while leaving foreign `SessionStart` hooks other tools registered untouched). Without either flag, `setup` leaves team-mode state alone — it's not a default, it's a per-run opt-in/opt-out.

## Preamble: bootstrap + shared source

Each skill body runs a two-step preamble in its very first bash block:

1. **Bootstrap** — ~12 lines inline in each `SKILL.md`. Resolves `LINEAR_SDLC_ROOT` from the skill's symlink target (probing both `~/.claude/skills/brainstorm/SKILL.md` and the `linear-sdlc-brainstorm` prefixed variant), falling back to `lsdlc-config get source_dir`. Exports `LINEAR_SDLC_ROOT`.

2. **Source the shared preamble** — `SKILL_NAME=<name> . "$LINEAR_SDLC_ROOT/references/preamble.sh"`. This file holds the parts that every skill needs identically: safe `LINEAR_API_KEY` loading (no `.`-sourcing), git branch + project slug detection, state dir creation, and the `lsdlc-timeline-log` "started" event. Having one source of truth means the security-critical env loader and the project detection can't drift across skills.

After sourcing, each `SKILL.md` prints its own info lines (learnings count, wiki pages, last session, checkpoints, last health score — whichever matter to that skill) and then `echo "---"`.

Skills reference repo files like `$LINEAR_SDLC_ROOT/templates/spec-template.md`. **Do not** use `${CLAUDE_PLUGIN_ROOT}` — that's a v1 (plugin-era) variable and no longer set.

**When editing the shared preamble:** changes to `references/preamble.sh` are picked up automatically by every skill on the next run — no per-skill edit or reinstall needed. The bootstrap block in each `SKILL.md` is intentionally minimal and should only change if the symlink layout changes.

## Linear access: `bin/lsdlc-linear`

`bin/lsdlc-linear` is a Node script that wraps Linear's GraphQL API. Skills call it for every Linear operation. Subcommands: `whoami`, `search-issues`, `list-assigned`, `get-issue`, `set-status`, `create-issue`, `add-relation`. All output is JSON on stdout.

**Critical safety rule:** the API key is read from `process.env.LINEAR_API_KEY` (with a fallback to parsing `~/.linear-sdlc/env` in pure JS). It **never** appears on argv, in shell strings, or in error output. If you add a new subcommand or refactor the helper, preserve this invariant — a key containing `$`, `'`, or backticks would break shell quoting in unsafe ways. Use `process.env` only.

The skills do not branch on whether the official Linear MCP server is installed. They always call `lsdlc-linear`. The official MCP is mentioned in setup output and the README as a nice-to-have for ad-hoc Linear queries the user types directly into Claude — but skills don't depend on it.

## State directory

```
~/.linear-sdlc/
├── env                                # LINEAR_API_KEY (mode 0600), if you used setup's prompt
├── config.json                        # team id, prefs, source_dir, wiki_scope, wiki_linear_*, ...
├── last-update-check                  # update-check cache: "<result> <local> <remote> <ts>"
├── update-snoozed                     # "<version> <level> <epoch>" when the user picks "Not now"
├── just-upgraded-from                 # "<old> <new>" marker, shown once after a /upgrade
├── .wiki-upgrade-pending              # one-time notice marker (preamble shows + deletes)
├── .wiki-scope-initialized            # setup-remember marker for wiki_scope handling
├── .last-session-update               # team-mode throttle timestamp (epoch seconds, 1h window)
├── .session-update.lock               # team-mode PID lockfile (auto-cleanup of stale PIDs)
├── analytics/session-update.log       # team-mode worker log (decisions + fetch/reset/setup output)
└── projects/<slug>/                   # slug derived from git remote
    ├── learnings.jsonl                # PRIVATE operational notes (append-only, confidence decay)
    ├── timeline.jsonl                 # skill execution log
    ├── <branch>-reviews.jsonl         # specialist findings per branch
    ├── health-history.jsonl           # /health score trend
    ├── wiki/                          # ONLY under wiki_scope=private (legacy layout)
    └── checkpoints/                   # /checkpoint session state
```

**The wiki lives in the user's repo by default** — not in `~/.linear-sdlc/`.
Under `wiki_scope=repo` (the fresh-install default), it's at
`<user-repo-root>/.linear-sdlc/wiki/`, committed via git so teammates share
it. Under `wiki_scope=private` it falls back to the legacy
`~/.linear-sdlc/projects/<slug>/wiki/` per-user layout. Under
`wiki_scope=off` it's disabled entirely.

### Three-layer wiki model

Per `thoughts/llm_wiki.md`:

1. **Raw sources** (immutable): code in the user's repo + Linear tickets
   (read via `lsdlc-linear`) + private `learnings.jsonl` + files dropped
   in `<wiki>/sources/`.
2. **The wiki** (LLM-owned): `entities/`, `concepts/`, `tickets/`,
   `incidents/`, `queries/` plus `index.md` and `log.md`. Authored by
   Claude, reviewed by the user in `git diff`.
3. **The schema** (co-evolved): `<wiki>/CLAUDE.md`. Scoped by directory
   proximity so Claude Code only reads it when editing files inside the
   wiki subtree. Scaffolded from `references/wiki-schema-template.md` by
   `/wiki init`.

`/implement` and `/debug` auto-ingest on successful completion (the
"fan-out" pattern — one source touches 10+ pages). Every write goes
through a hard `lsdlc-wiki secret-scan` gate. Nothing auto-commits.

Override the state dir for tests: `LSDLC_STATE_DIR=/tmp/test-state ./setup`. All bin scripts and the skill preamble respect this.

## Autoupdate

The shared preamble runs `bin/lsdlc-update-check` on every skill invocation. It's silent on the happy path; when a newer release is available it prints `UPDATE_AVAILABLE <old> <new>` plus a one-line `NOTE_TO_CLAUDE:` directive telling Claude to dispatch to `/upgrade` before resuming the current skill. The `/upgrade` skill (`skills/upgrade/SKILL.md`) then runs the Yes / Always / Not now / Never ask again dialog and, on Yes, runs `git fetch origin && git reset --hard origin/main && ./setup --skip-api-key --skip-mcp-prompt -q`.

**Design choices** (see `bin/lsdlc-update-check` header for the full rationale):
- **Split-TTL cache:** `UP_TO_DATE` expires after 60 min (detect new releases quickly), `UPGRADE_AVAILABLE` after 12 h (nag persistently without spamming the network).
- **Escalating snooze:** "Not now" responses cumulate 24 h → 48 h → 7 d. A new remote version voids the old snooze — the user always hears about real news.
- **Offline-safe:** curl failures are treated as UP_TO_DATE and no cache entry is written, so the next invocation retries.
- **Config-based opt-out:** `lsdlc-config set update_check false` silences all checks; `auto_upgrade true` runs the upgrade without a dialog.

**Release process** — bump `VERSION` and add a `CHANGELOG.md` entry in the same commit, then tag. `bin/lsdlc-update-check` fetches the raw `VERSION` file from `main`, so the moment `VERSION` is pushed, users start seeing the banner on their next skill invocation (subject to their cache TTL).

**Team mode (opt-in background updater).** `./setup --team` registers a `SessionStart` hook in `~/.claude/settings.json` that runs `bin/lsdlc-session-update` on every Claude Code session start. The worker is forked into the background immediately (exit 0, never blocks session startup), throttled to once per hour via `~/.linear-sdlc/.last-session-update`, PID-locked via `~/.linear-sdlc/.session-update.lock`, and logs all decisions and outcomes to `~/.linear-sdlc/analytics/session-update.log`. It self-gates on two config flags — `team_mode: true` and `update_check != false` — so even with the hook still registered, users can disable it via `lsdlc-config set team_mode false` or `lsdlc-config set update_check false` without editing `settings.json`. `./setup --no-team` performs the clean teardown: unsets `team_mode` and `auto_upgrade`, then calls `bin/lsdlc-settings-hook remove "$HOME/.local/bin/lsdlc-session-update"` which preserves any foreign `SessionStart` hooks other tools have registered.

**`bin/lsdlc-settings-hook` ownership rules:** the helper only adds/removes entries whose `command` exactly matches the argument passed in. An `add` inserts a fresh wrapper entry (`{ hooks: [{ type, command }] }`) rather than merging into an existing one, so a later `remove` can strip exactly what was added without touching other tools' hooks. It refuses to write if `settings.json` is not valid JSON (prints an error and exits 1). Writes are atomic via temp-file + rename, mode `0600`.

**Drift guard:** only the shared preamble and the `/upgrade` skill should call `lsdlc-update-check`. If any other skill body invokes it directly, fold the call back into `references/preamble.sh`.

```bash
# Expect exactly one hit: skills/upgrade/SKILL.md (which forces a fresh check).
grep -rn 'lsdlc-update-check' skills/
```

## Hacking on the repo

- **Edit a skill:** modify `skills/<skill>/SKILL.md` directly in the checkout. Symlinks pick up changes on the next Claude Code session — no reinstall.
- **Add a skill:** create `skills/<new-skill>/SKILL.md` with the standard frontmatter, then re-run `./setup`. It gets symlinked automatically.
- **Test `lsdlc-linear` in isolation:** export a `LINEAR_API_KEY` (or rely on the env file), then run `bin/lsdlc-linear whoami`. Output is JSON; pipe through `jq` if you have it.
- **Test with a throwaway state dir:** `LSDLC_STATE_DIR=/tmp/test-state ./setup --skip-api-key --skip-mcp-prompt`.
- **Verify YAML frontmatter:** there's no build step. After editing a skill, `head -15 skills/<skill>/SKILL.md` and visually check.
- **Catch regressions to plugin-era references:**
  ```bash
  grep -rn 'CLAUDE_PLUGIN_ROOT\|user_config\.linear_api_key\|Use the Linear MCP\|via Linear MCP' \
    skills/ references/
  ```
  Should return zero hits. If anything turns up, that's a v1 leak.
- **Verify no skill has drifted away from the shared preamble:**
  ```bash
  grep -rln 'preamble.sh' skills/   # expect exactly 10 files (one per skill, incl. /wiki and /update-tickets)
  grep -rn  'LINEAR_API_KEY' skills/  # expect zero hits — only the shared preamble loads it
  ```
  If a skill has its own env-sourcing block, fold it back into `references/preamble.sh` — we explicitly don't want the RCE-relevant code duplicated.
- **Wiki path regressions:**
  ```bash
  # No skill should construct $_PROJ/wiki — the wiki path is resolved by
  # the shared preamble via `lsdlc-wiki path` and exported as $_WIKI.
  grep -rn '\$_PROJ/wiki' skills/ references/ bin/
  ```
  Should return zero hits (except in `bin/lsdlc-wiki` and `bin/lsdlc-wiki-ingest` which are the plumbing that owns that path during `migrate`).
- **Secrets never on argv:**
  ```bash
  grep -rn 'LINEAR_API_KEY' bin/ references/
  ```
  Should return hits ONLY in `references/preamble.sh` (the safe loader) and `bin/lsdlc-linear` (reads `process.env.LINEAR_API_KEY`). Any new code path must use `process.env` — never interpolate the key into shell strings or argv.

## Conventions

- **Skill bodies invoke `bin/` scripts as bare commands.** Setup symlinks them into `~/.local/bin`, which is on the user's `PATH` (or setup warns at install time). Don't write `${CLAUDE_PLUGIN_ROOT}/bin/lsdlc-slug` — that path no longer exists.
- **Reference repo files via `$LINEAR_SDLC_ROOT/...`.** The preamble exports it.
- **Model and effort defaults are tuned for typical workloads, not worst case.** Brainstorm is opus/medium (synthesis for feature planning); implement is sonnet/medium (most tickets are small, heavy reasoning happens in specialist sub-agents). Changing a skill's model/effort means updating three places in lockstep: skill frontmatter, README "Skills" table, and ETHOS.md "Right Model for the Job" section. Miss any and the docs lie.
- **Never interpolate secrets into `node -e` string literals.** Pass via `process.env` (e.g., `LINEAR_API_KEY=$LINEAR_API_KEY node -e '...'` won't work because the heredoc is the wrong shape; do it inside `bin/lsdlc-linear` instead, where the helper reads `process.env` natively).
- **Commits:** no `Co-Authored-By: Claude` trailers, no "Generated with Claude Code" lines (also a global preference in `~/.claude/CLAUDE.md`).
- **Skill invocation in docs:** use the bare form (`/brainstorm`) since that's the default. If a doc paragraph also needs to mention the prefixed form, write `/linear-sdlc-brainstorm` (note the dash, not the colon — the colon was a v1 plugin convention).

## Testing without breaking the real world

- **Throwaway state:** `LSDLC_STATE_DIR=$(mktemp -d) ./setup --skip-api-key --skip-mcp-prompt` exercises the skill-symlink path without touching real config.
- **Throwaway HOME:** `HOME=$(mktemp -d) ./setup` to verify the API-key prompt and team-id prompt against a fresh state.
- **Skill smoke test:** after setup, `cat ~/.claude/skills/brainstorm/SKILL.md | head -20` should resolve through the symlink and show the frontmatter.
- **Helper smoke test:** `lsdlc-linear --help` (no API key needed) prints usage. `lsdlc-linear whoami` (with a real key) hits the API.
