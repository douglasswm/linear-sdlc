# linear-sdlc — notes for Claude

This repo is a Claude Code **skills pack** that implements a Linear-driven SDLC workflow. Read `README.md` for the user-facing description; this file is for agents working on the repo itself.

## Layout

```
linear-sdlc/
├── setup                              # bash installer (idempotent, gstack-style)
├── bin/
│   ├── lsdlc-slug                     # derive project slug + branch from git
│   ├── lsdlc-config                   # read/write ~/.linear-sdlc/config.json
│   ├── lsdlc-timeline-log             # append skill events to timeline.jsonl
│   ├── lsdlc-learnings-log            # append learnings to learnings.jsonl
│   ├── lsdlc-learnings-search         # query learnings with confidence decay
│   ├── lsdlc-wiki-ingest              # synthesize learnings into wiki pages
│   ├── lsdlc-wiki-lint                # check wiki freshness
│   └── lsdlc-linear                   # Linear GraphQL helper (Node, zero deps)
├── skills/
│   ├── brainstorm/SKILL.md            # /brainstorm — feature planning
│   ├── create-tickets/SKILL.md        # /create-tickets — spec → Linear issues
│   ├── next/SKILL.md                  # /next — pick next ticket
│   ├── implement/
│   │   ├── SKILL.md                   # /implement — full ticket lifecycle
│   │   └── specialists/               # checklists consumed by parallel sub-agents
│   │       ├── testing.md
│   │       ├── security.md
│   │       ├── performance.md
│   │       └── code-quality.md
│   ├── debug/SKILL.md                 # /debug — bug investigation
│   ├── checkpoint/SKILL.md            # /checkpoint — save/resume state
│   └── health/SKILL.md                # /health — code quality dashboard
├── references/
│   ├── preamble.md                    # shared bash block + LINEAR_SDLC_ROOT resolver
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
├── config.json                        # team id, prefs, source_dir
└── projects/<slug>/                   # slug derived from git remote
    ├── learnings.jsonl                # append-only operational notes (with confidence decay)
    ├── timeline.jsonl                 # skill execution log
    ├── <branch>-reviews.jsonl         # specialist findings per branch
    ├── health-history.jsonl           # /health score trend
    ├── wiki/                          # synthesized knowledge pages
    └── checkpoints/                   # /checkpoint session state
```

Override the state dir for tests: `LSDLC_STATE_DIR=/tmp/test-state ./setup`. All bin scripts and the skill preamble respect this.

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
  grep -rln 'preamble.sh' skills/   # expect exactly 7 files
  grep -rn  'LINEAR_API_KEY' skills/  # expect zero hits — only the shared preamble loads it
  ```
  If a skill has its own env-sourcing block, fold it back into `references/preamble.sh` — we explicitly don't want the RCE-relevant code duplicated.

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
