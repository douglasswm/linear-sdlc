# linear-sdlc — notes for Claude

This repo is a Claude Code **plugin** that implements a Linear-driven SDLC workflow. Read `README.md` for the user-facing description; this file is for agents working on the repo itself.

## Layout

- `.claude-plugin/plugin.json` — plugin manifest. `name: linear-sdlc` becomes the invocation prefix (`/linear-sdlc:<skill>`). Declares `userConfig` (Linear API key + team ID) and references `.mcp.json` for the Linear MCP server.
- `.claude-plugin/marketplace.json` — marketplace catalog so users can `/plugin marketplace add git@github.com:douglasswm/linear-sdlc.git`.
- `.mcp.json` — Linear MCP server definition. Reads `LINEAR_API_KEY` from `${user_config.linear_api_key}`, which Claude Code sources from the OS keychain.
- `skills/<skill>/SKILL.md` — one per workflow: `brainstorm`, `create-tickets`, `next`, `implement`, `debug`, `checkpoint`, `health`. **Skills directly create the slash commands** — `skills/brainstorm/SKILL.md` is invoked as `/linear-sdlc:brainstorm`. Each file has YAML frontmatter (`name`, `description`, `model`, `effort`, `argument-hint`, `allowed-tools`) followed by the prompt body. **`disable-model-invocation` is intentionally NOT set** — both slash invocation and Claude auto-invocation are wanted: the `description: Use when: ...` clauses are trigger hints that let Claude pull a skill in when the user says "let me debug this" without typing a slash. User Sovereignty is enforced inside each workflow (explicit confirmation gates before destructive actions), not at the invocation layer. The legacy `commands/` directory is **not** used.
- `skills/implement/specialists/*.md` — checklists consumed by parallel sub-agents during `/linear-sdlc:implement`'s self-review phase (testing, security, performance, code-quality).
- `bin/lsdlc-*` — shell helpers for state management. `lsdlc-slug` derives the project slug from the git remote, `lsdlc-config` reads/writes `~/.linear-sdlc/config.json`, `lsdlc-learnings-*` and `lsdlc-timeline-log` append to JSONL state files, `lsdlc-wiki-*` synthesize learnings into markdown pages. **Skill bodies invoke them as bare command names** (e.g., `lsdlc-slug`, not `${CLAUDE_PLUGIN_ROOT}/bin/lsdlc-slug`). Per Claude Code's plugin spec, the plugin's `bin/` is automatically added to the Bash tool's `PATH` whenever the plugin is enabled.
- `templates/spec-template.md` — the spec file `/linear-sdlc:brainstorm` writes and `/linear-sdlc:create-tickets` reads.
- `references/` — shared prompt fragments (preamble, ask-user-format, completion-status, verification-gate) included by skill bodies.
- `ETHOS.md` — design principles. **Keep in sync with reality** — when changing model defaults or workflow behavior, update ETHOS too or it becomes a lie.
- `CHANGELOG.md` — release notes.

## Installation

Users install via Claude Code's plugin system:

```
/plugin marketplace add git@github.com:douglasswm/linear-sdlc.git
/plugin install linear-sdlc@linear-sdlc
```

The Linear API key is collected at install time via `userConfig` (`sensitive: true`) and stored in the OS keychain (macOS Keychain, Linux Secret Service, Windows Credential Manager). Claude Code interpolates it into the MCP server's env block at startup. There is no separate setup script.

For local development on this repo, use `--plugin-dir`:

```bash
claude --plugin-dir /Users/douglasswm/Project/AAS/linear-sdlc
```

This loads the plugin straight from the repo without going through marketplace install — edits to skill files take effect on the next session.

## State directory

Persistent state lives outside the repo at `~/.linear-sdlc/`:

```
~/.linear-sdlc/
├── config.json                       # linear_team_id, user prefs
└── projects/<slug>/
    ├── learnings.jsonl               # append-only operational notes
    ├── timeline.jsonl                # skill execution log
    ├── <branch>-reviews.jsonl        # specialist findings per branch
    ├── health-history.jsonl          # /linear-sdlc:health score trend
    ├── wiki/                         # synthesized knowledge
    └── checkpoints/                  # /linear-sdlc:checkpoint session state
```

Slug is derived from the git remote. Each repo gets isolated state.

## Testing changes without breaking the real world

- **Local plugin loop:** `claude --plugin-dir /Users/douglasswm/Project/AAS/linear-sdlc` is the fast feedback path. Changes to skill files apply on the next session — no reinstall, no marketplace fetch.
- **Full marketplace install (rarer):** `/plugin marketplace add file:///Users/douglasswm/Project/AAS/linear-sdlc` followed by `/plugin install linear-sdlc@linear-sdlc` simulates the real user flow end-to-end. Use this before tagging a release.
- **Throwaway HOME:** if you want to verify the API-key prompt and keychain write without touching your real keychain, run Claude Code with `HOME=$(mktemp -d) claude` and install the plugin from there.
- **Skill frontmatter:** after changing `model:` or `effort:`, verify the YAML parses by running `head -15 skills/<skill>/SKILL.md` and visually checking. There is no build step.
- **Bin scripts:** most read/write `~/.linear-sdlc/`. Use `LSDLC_STATE_DIR=/tmp/test-state <script>` when one supports the env override (check the script source — `lsdlc-config` does).
- **Path references in skill bodies:** invoke `bin/` scripts as **bare command names** (e.g., `lsdlc-slug`) — Claude Code adds the plugin's `bin/` to `PATH` automatically. Use `${CLAUDE_PLUGIN_ROOT}/templates/...` for `templates/` references (templates dir is not on PATH). After editing, run `grep -rn '~/.claude/skills/linear-sdlc' skills/ references/` and confirm zero hits — any old-style path is a regression.

## Conventions

- **Model and effort defaults:** tuned for typical workloads, not worst case. `brainstorm` is `opus/medium` (synthesis for feature planning), `implement` is `sonnet/medium` (most tickets are small, heavy reasoning happens in specialist sub-agents). See `README.md` "Why different models?" for per-skill rationale. If you change these, update the README table *and* the ETHOS.md "Right Model for the Job" section or they drift.
- **Model changes = three places:** skill frontmatter, README table, ETHOS.md. Miss any and the docs lie.
- **Skill invocation in docs:** always use the namespaced form `/linear-sdlc:brainstorm`, never the bare `/brainstorm`. The bare form was the old skill-pack era and no longer works.
- **Never interpolate secrets into `node -e` string literals.** The Linear API key is passed via `process.env` for a reason — a key containing `$`, `'`, or backticks would break JSON or execute JS. (This was a `setup`-script-era rule but still applies to any bin script that touches the key.)
- **Commits:** no `Co-Authored-By: Claude` trailers, no "Generated with Claude Code" lines (this is also a global preference in `~/.claude/CLAUDE.md`).
