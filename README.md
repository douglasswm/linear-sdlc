# linear-sdlc

A complete SDLC workflow for teams using Linear + Claude Code. Ticket-driven development with specialist code reviews, knowledge accumulation, and quality monitoring — distributed as a skills pack you clone, install, and own.

## Prerequisites

- **Claude Code** (the `claude` CLI)
- **Git**
- **Node 18+** — required for built-in `fetch` (used by `bin/lsdlc-linear`)
- **GitHub CLI (`gh`)** — required by `/implement` for PR creation
- **Linear API key** — create one at [linear.app/settings/api](https://linear.app/settings/api)

## Installation

```bash
git clone git@github.com:douglasswm/linear-sdlc.git ~/.claude/skills/linear-sdlc
cd ~/.claude/skills/linear-sdlc
./setup
```

`./setup` is interactive and idempotent. It:

- Checks prereqs and resolves the repo path
- Asks whether you want **short** skill names (`/brainstorm`) or **namespaced** ones (`/linear-sdlc-brainstorm`); short is the default and remembered for next time
- Creates skill symlinks under `~/.claude/skills/` (one per skill, so Claude Code discovers them as top-level commands)
- Symlinks the helper scripts under `bin/` into `~/.local/bin/` so the skills can call them as bare commands (warns if `~/.local/bin` isn't on your `PATH`)
- Prompts for your **Linear API key** and writes it to `~/.linear-sdlc/env` (mode `0600`) — see [API key storage](#api-key-storage) below
- Prompts for your **Linear team key** (e.g., `VER`) and saves it to `~/.linear-sdlc/config.json`
- Prints how to install the official Linear MCP server **separately** if you want it (we don't install it for you — see [Why we don't embed an MCP server](#why-we-dont-embed-an-mcp-server))

You can re-run `./setup` any time. Existing values default to "keep". Switch naming with `./setup --prefix` / `./setup --no-prefix`.

### Updating

```bash
cd ~/.claude/skills/linear-sdlc
git pull
./setup
```

`./setup` re-links symlinks (idempotent) and respects your saved config.

### Uninstalling

```bash
# Remove symlinks
rm -rf ~/.claude/skills/{brainstorm,next,implement,create-tickets,checkpoint,debug,health}
rm -f  ~/.local/bin/lsdlc-*
# Remove the checkout
rm -rf ~/.claude/skills/linear-sdlc
# Optional: wipe project state (learnings, timelines, checkpoints, wiki)
rm -rf ~/.linear-sdlc
```

If you used `--prefix`, replace the skill names above with `linear-sdlc-brainstorm`, `linear-sdlc-next`, etc.

### Migrating from v1 (the plugin era)

v1.0.x of linear-sdlc was packaged as a Claude Code plugin. v2 is a clean break — no plugin, no embedded MCP server, no marketplace install. To migrate:

1. **Uninstall the v1 plugin** in Claude Code:
   ```
   /plugin uninstall linear-sdlc@linear-sdlc
   ```
2. **Manually remove the OS keychain entry** for `linear_api_key`. On macOS, find it in Keychain Access by searching for "linear" or "claude-code"; on Linux, use your distro's secret-service tool; on Windows, Credential Manager. (Claude Code does not currently expose a keychain-cleanup command for plugin secrets.)
3. **Clone and run `./setup`** as above. Your `~/.linear-sdlc/projects/` state directory survives the migration intact — learnings, timelines, checkpoints, wiki pages, and per-branch review files all carry over.

## Why we don't embed an MCP server

The previous (v1) plugin shipped a reference to `@anthropic-ai/linear-mcp-server` and registered it via plugin `userConfig`. That had a bunch of subtle problems:

- `npx -y` resolution against the user's local Node, with no version pinning
- `${user_config.linear_api_key}` interpolation that fought with Claude Code's `/doctor` checker
- Reconnect failures after `/plugin config` (we hit one in this very session)
- Hardcoded dependency on a single MCP package whose name has shifted over time

The cleaner path is to **delegate to vendor-maintained MCP servers**. Linear themselves publish a first-party HTTP MCP at `https://mcp.linear.app/mcp` with proper OAuth, dynamic client registration, and Linear-managed updates. You install it once with one command:

```bash
claude mcp add --transport http linear https://mcp.linear.app/mcp
```

Then run `/mcp` inside a Claude Code session to complete the OAuth flow in your browser. After that, ad-hoc Linear queries ("list my open cycles", "what's blocking VER-42", etc.) work in any Claude Code session.

**linear-sdlc skills do not depend on this.** They use direct Linear GraphQL via the bundled `bin/lsdlc-linear` helper, which reads `LINEAR_API_KEY` from your environment. Install the official MCP if you want richer ad-hoc queries; skip it if you don't. Either way, the skills behave the same.

## The `lsdlc-linear` helper

`bin/lsdlc-linear` is a zero-dependency Node script that wraps Linear's GraphQL API. It reads `LINEAR_API_KEY` from the environment (falling back to `~/.linear-sdlc/env`) and outputs JSON to stdout. The skills call it directly via Bash; nothing in the helper ever puts the API key on the command line or in error output.

| Subcommand | Purpose |
|---|---|
| `lsdlc-linear whoami` | Print the authenticated viewer (sanity check for the API key) |
| `lsdlc-linear search-issues "<query>" [--team KEY] [--limit N]` | Full-text search across the workspace |
| `lsdlc-linear list-assigned [--team KEY] [--status "Todo,Backlog"] [--limit N]` | Issues assigned to you, filtered by state name |
| `lsdlc-linear get-issue VER-42` | Full ticket: title, description, parent, children, relations, labels, comments |
| `lsdlc-linear set-status VER-42 "In Progress"` | Move a ticket between workflow states (resolves the state name on the issue's team) |
| `lsdlc-linear create-issue --title "..." [--description "..."] [--team KEY] [--priority N] [--labels l1,l2] [--parent VER-40]` | Create an issue, optionally with a parent and labels |
| `lsdlc-linear add-relation VER-42 blockedBy VER-41` | Add a `blocks` / `blockedBy` relation between two issues |

Try it:

```bash
lsdlc-linear whoami
lsdlc-linear list-assigned --team VER --status "Todo,Backlog" --limit 5
```

Pipe the output through `node -e` for inline parsing, or feed it through `jq` if you have it installed.

## API key storage

`./setup` writes your Linear API key to `~/.linear-sdlc/env` with mode `0600`:

```bash
# linear-sdlc env — sourced by bin/lsdlc-linear and the skill preamble.
export LINEAR_API_KEY='lin_api_...'
```

This is plain-text storage. The threat model is "another user on the same machine reading my files" — `0600` protects against that, but anyone with root can still read it. If that's too loose for you, the helper reads `LINEAR_API_KEY` from any source — pick one of these instead:

**1Password CLI:**
```bash
export LINEAR_API_KEY="$(op read 'op://Private/Linear/api-key')"
```

**direnv** (project-local `.envrc`):
```bash
export LINEAR_API_KEY="<your key>"
```

**Shell rc** (`~/.zshrc` / `~/.bashrc`):
```bash
export LINEAR_API_KEY='lin_api_...'
```

If `LINEAR_API_KEY` is already in the environment when a skill runs, the preamble does NOT source `~/.linear-sdlc/env` — your shell-provided value wins.

Use `./setup --skip-api-key` to opt out of writing the env file entirely.

## State directory

All persistent state lives at `~/.linear-sdlc/`:

```
~/.linear-sdlc/
├── env                              # API key (mode 0600), if you used setup's prompt
├── config.json                      # team ID, prefs (managed by lsdlc-config)
└── projects/
    └── {slug}/                      # per-project (slug derived from git remote)
        ├── learnings.jsonl          # operational notes (append-only, with confidence decay)
        ├── timeline.jsonl           # skill execution history
        ├── {branch}-reviews.jsonl   # specialist review findings per branch
        ├── health-history.jsonl     # /health score trend
        ├── wiki/                    # synthesized knowledge pages
        │   ├── index.md
        │   └── log.md
        └── checkpoints/             # /checkpoint session state
```

Override the location with `LSDLC_STATE_DIR=/path/to/state`.

## Bin scripts

| Script | Purpose |
|---|---|
| `lsdlc-slug` | Derive project slug + branch from git context |
| `lsdlc-config` | Read/write `config.json` (`get`, `set`, `list`) |
| `lsdlc-timeline-log` | Append skill events to `timeline.jsonl` |
| `lsdlc-learnings-log` | Append operational learnings to `learnings.jsonl` |
| `lsdlc-learnings-search` | Search learnings with confidence decay and dedup |
| `lsdlc-wiki-ingest` | Synthesize learnings into wiki pages (3+ per topic) |
| `lsdlc-wiki-lint` | Check wiki for stale or inconsistent content |
| `lsdlc-linear` | Direct Linear GraphQL helper (see [above](#the-lsdlc-linear-helper)) |

After `./setup`, all of these are on your `PATH` via `~/.local/bin/`. You can call them from any terminal — they're not Claude-specific.

## Skills

Each skill is a single `SKILL.md` file with YAML frontmatter declaring its model and effort. `./setup` symlinks each skill into `~/.claude/skills/` so Claude Code discovers it as a top-level command.

| Skill | Description | Model | Effort |
|---|---|---|---|
| `/brainstorm` | Plan new features, search Linear for duplicates, write specs | Opus | Medium |
| `/create-tickets` | Convert spec files into Linear issues with dependencies | Sonnet | Medium |
| `/next` | Query Linear for unblocked tickets, recommend what to work on | Haiku | Low |
| `/implement` | Full lifecycle: ticket → branch → code → specialist review → PR | Sonnet | Medium |
| `/debug` | Systematic bug investigation with component-boundary evidence | Sonnet | Medium |
| `/checkpoint` | Save/resume working state across sessions | Sonnet | Low |
| `/health` | Code quality dashboard with composite scoring | Sonnet | Medium |

(Names above assume the default `--no-prefix` install. With `--prefix`, they become `/linear-sdlc-brainstorm`, etc.)

**Why different models?** Defaults are tuned for cost and latency on typical work, not worst case:

- **`/brainstorm`** uses **Opus** because feature planning benefits from cross-domain synthesis. Medium effort is plenty for interactive Q&A.
- **`/implement`** uses **Sonnet/Medium** because most tickets are small. Heavy reasoning happens in the parallel specialist sub-agents during self-review, and they pick their own depth.
- **`/debug`** uses **Sonnet/Medium** — diagnostic reasoning needs structure, not raw creativity.
- **`/create-tickets`** and **`/health`** use **Sonnet/Medium** — structured judgment.
- **`/next`** uses **Haiku/Low** — query, rank, present.
- **`/checkpoint`** uses **Sonnet/Low** — mechanical state dump/restore.

If a skill feels underpowered, edit the `model:` and `effort:` lines in `skills/<skill>/SKILL.md` directly — symlinks pick up the change on the next session.

## Usage

### Planning a new feature

```
/brainstorm rate limiting
```

Walks you through a structured discussion (problem, impact, scope, technical approach) and writes a spec to `specs/rate-limiting.md`. For features that span multiple subsystems, `/brainstorm` automatically switches into an inline **deep-design mode** — codebase grounding, 2-3 approach comparison, section-by-section design walkthrough with per-section approval.

When the spec is ready:

```
/create-tickets specs/rate-limiting.md
```

Creates a parent issue and sub-issues in Linear with proper blocking relationships, priorities, and labels — all via direct GraphQL through `lsdlc-linear`. You confirm the breakdown before anything is created.

### Picking what to work on

```
/next
```

Queries your assigned tickets, filters out blocked ones, ranks by priority and cycle deadline, and presents the top 3 with a recommendation.

### Implementing a ticket

```
/implement VER-42
```

Full lifecycle: load ticket context → pre-flight checks → set status to "In Progress" → create branch → code with you → run **specialist self-review** in parallel sub-agents (testing / security / performance / code-quality) → create PR via `gh` → set status to "In Review". Critical findings from specialists must be fixed before the PR is created.

### Debugging a bug

```
/debug
```

Reproduce → identify component boundaries → instrument → observe → hypothesize root cause → propose minimal fix. Evidence before hypothesis. Soft discipline — User Sovereignty still applies.

### Saving and resuming

```
/checkpoint            # save current state
/checkpoint resume     # load the most recent checkpoint
```

Captures git state, current ticket, completed/remaining work. Writes to `~/.linear-sdlc/projects/{slug}/checkpoints/`.

### Code health

```
/health
```

Auto-detects your project's quality tools (pytest/jest/vitest, eslint/biome/ruff, tsc/mypy/pyright, vulture/knip), runs each, and computes a weighted composite (tests 30%, lint 25%, types 25%, dead code 20%) with trend vs the previous run.

## How it works

### Direct GraphQL via `lsdlc-linear`

All Linear operations the skills perform — search, list, get, set status, create issues, create relations — go through `bin/lsdlc-linear`. The helper reads `LINEAR_API_KEY` from the environment (with the strict safety rule that the key never appears on argv or in error output) and POSTs to `https://api.linear.app/graphql` using Node 18+'s built-in `fetch`. No npm dependencies, no MCP server, no additional install steps.

If you've also installed Linear's official MCP server (recommended for ad-hoc queries — see [above](#why-we-dont-embed-an-mcp-server)), it coexists peacefully. Skills don't call it; you call it directly via Claude Code prompts.

### Specialist reviews

Before PR creation, `/implement` dispatches parallel sub-agents (via the `Agent` tool) that independently review the `git diff` against checklists in `skills/implement/specialists/`. Each specialist returns structured findings classified as **Critical** (must fix), **Warning** (discuss), or **Nit** (skip unless you want to address). Findings are deduplicated by file + line.

### Knowledge base

Two layers:

- **Learnings (JSONL)** — raw operational notes appended during skill execution. Each entry has a key, type, confidence score, and source (observed/inferred/documented). Confidence decays over time for observed/inferred entries (-1 point per 30 days).
- **Wiki pages (Markdown)** — synthesized knowledge created when 3+ learnings accumulate on a topic. Run `lsdlc-wiki-ingest` to generate wiki pages from learnings; `lsdlc-wiki-lint` to check for stale or inconsistent content.

Every skill loads relevant learnings at startup via the preamble, so context accumulates across sessions.

### Timeline

Every skill execution is logged to `timeline.jsonl` (start, completion, outcome). On session start, the preamble checks the timeline and surfaces what happened last on the current branch — helping you pick up where you left off.

## Hacking on linear-sdlc

The cloned checkout *is* the source of truth. Edit any `skills/*/SKILL.md`, `bin/*`, `references/*.md`, or `templates/*` file and the change takes effect on Claude Code's next session — symlinks make this loopless.

Adding a new skill:

1. Create `skills/your-skill/SKILL.md` with the standard YAML frontmatter (`name`, `description`, `model`, `effort`, `allowed-tools`).
2. Re-run `./setup` — the new skill gets symlinked automatically.

Editing an existing skill:

1. Edit `skills/<name>/SKILL.md` directly in the checkout.
2. No reinstall — Claude Code reads through the symlink on the next invocation.

Resetting state without touching keys:

```bash
mv ~/.linear-sdlc/projects ~/.linear-sdlc/projects.bak
```

## License

MIT
