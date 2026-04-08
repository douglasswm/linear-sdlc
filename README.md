# linear-sdlc

A complete SDLC workflow for teams using Linear + Claude Code. Ticket-driven development with specialist code reviews, knowledge accumulation, and quality monitoring.

## Prerequisites

Before installing, make sure you have:

- **Claude Code** with plugin support
- **Node.js** — Required for the Linear MCP server (`node --version` to check)
- **GitHub CLI** — Required for PR creation (`gh --version` to check, install with `brew install gh`)
- **Git** — Required for branch management
- **Linear API key** — Go to [Linear Settings → API → Personal API keys](https://linear.app/settings/api) and create one

## Installation

linear-sdlc is distributed as a Claude Code plugin.

### Install

In a Claude Code session, run:

```
/plugin marketplace add git@github.com:douglasswm/linear-sdlc.git
/plugin install linear-sdlc@linear-sdlc
/reload-plugins
```

The `marketplace.json` and `plugin.json` are both named `linear-sdlc`, so the install target is `linear-sdlc@linear-sdlc` (`<plugin>@<marketplace>`). Claude Code prompts you for your Linear API key on enable; the key is stored in your OS keychain (macOS Keychain, Linux Secret Service, Windows Credential Manager) — never in plaintext config files.

### Verify

Ask Claude: **"List my Linear teams"**. If the MCP server is working, you'll see your team(s) returned. You can also type `/help` and look for the `linear-sdlc:` skills under "custom-commands".

### Discoverability tip

In current Claude Code releases, typing `/linear-sdlc:` doesn't always pop the autocomplete menu, but the skills are loaded — type the full slash command (e.g., `/linear-sdlc:brainstorm rate limiting`) and it runs. `/help` lists every available skill with its description.

### Updating

```
/plugin update linear-sdlc@linear-sdlc
/reload-plugins
```

### Uninstalling

```
/plugin uninstall linear-sdlc@linear-sdlc
```

This removes the plugin and the MCP server registration. Your project state (`~/.linear-sdlc/projects/*/`) is preserved — delete it manually if you want a clean slate.

### Local development

If you're hacking on the plugin itself, the fast iteration loop is:

1. **Once:** install via the marketplace flow above so the API key gets written to your OS keychain.
2. **Then:** quit Claude Code and restart with `--plugin-dir` pointing at your local checkout:
   ```bash
   claude --plugin-dir /path/to/linear-sdlc
   ```
   The local checkout takes precedence over the installed marketplace copy for that session, but the userConfig (API key) is reused from the keychain — so the Linear MCP server still works without re-prompting.
3. As you edit skill files, run `/reload-plugins` inside the session to pick up changes without restarting.

## Skills

Each skill is configured with an appropriate Claude model and effort level to balance reasoning depth with speed and cost.

| Skill | Description | Model | Effort |
|-------|-------------|-------|--------|
| `/linear-sdlc:brainstorm` | Plan new features, search for duplicates, write specs | Opus | Medium |
| `/linear-sdlc:create-tickets` | Convert spec files into Linear issues with dependencies | Sonnet | Medium |
| `/linear-sdlc:next` | Query Linear for unblocked tickets, recommend what to work on | Haiku | Low |
| `/linear-sdlc:implement` | Full lifecycle: ticket → branch → code → specialist review → PR | Sonnet | Medium |
| `/linear-sdlc:debug` | Systematic bug investigation with component-boundary evidence | Sonnet | Medium |
| `/linear-sdlc:checkpoint` | Save/resume working state across sessions | Sonnet | Low |
| `/linear-sdlc:health` | Code quality dashboard with composite scoring | Sonnet | Medium |

**Why different models?** Defaults are tuned for cost and latency on typical tickets, not worst-case complexity:

- **`/linear-sdlc:brainstorm`** uses **Opus** because feature planning benefits from cross-domain synthesis and catching subtle product nuance. Medium effort is plenty for interactive Q&A — high effort is wasted when the human drives the pace.
- **`/linear-sdlc:implement`** uses **Sonnet/Medium** because most tickets are small (one or two files, a handful of acceptance criteria). The heavy reasoning during specialist self-review runs in parallel sub-agents that can decide their own depth. For a genuinely architectural ticket, either run `/linear-sdlc:brainstorm` first to front-load the thinking, or manually bump `skills/implement/SKILL.md` to `opus`/`high` for that session.
- **`/linear-sdlc:debug`** uses **Sonnet/Medium** — diagnostic reasoning needs structure (component-boundary evidence, hypothesis discipline) but not Opus-level creativity. Medium effort leaves room for the soft invariant "observe before hypothesizing".
- **`/linear-sdlc:create-tickets`** and **`/linear-sdlc:health`** use **Sonnet/Medium** — structured work with enough judgment (dependency inference, scoring) to benefit from medium effort.
- **`/linear-sdlc:next`** uses **Haiku/Low** — it's a query, a rank, and a presentation. Haiku is faster and sufficient.
- **`/linear-sdlc:checkpoint`** uses **Sonnet/Low** — mostly mechanical state dump/restore.

If a skill feels underpowered for your work, fork the plugin repo and edit the `model:` and `effort:` lines in that skill's `SKILL.md`.

## Usage

### Planning a new feature

Start with `/linear-sdlc:brainstorm` to explore the idea, search Linear for existing related tickets, and write a spec file:

```
/linear-sdlc:brainstorm rate limiting
```

This walks you through a structured discussion (problem, impact, solution shape, scope, technical approach) and writes a spec to `specs/rate-limiting.md`.

**Deep design mode.** For features that span multiple subsystems, require architecture decisions, or need a formal design process, `/linear-sdlc:brainstorm` automatically switches into an inline **deep-design mode**: it scans the codebase for grounding, proposes 2–3 approaches with a trade-off table, walks through the chosen design section-by-section (data model → API → failure modes → rollout) with per-section approval, and runs a self-review checklist before writing the spec. No external skills or plugins required — it's all inline.

When the spec is ready, convert it to Linear tickets:

```
/linear-sdlc:create-tickets specs/rate-limiting.md
```

This creates a parent issue and sub-issues in Linear with proper dependencies, priorities, and labels. You confirm the breakdown before anything is created. If the spec touches three or more subsystems, `/linear-sdlc:create-tickets` will also ask whether to bundle them under one parent or split into multiple parents for independent release trains.

### Picking what to work on

```
/linear-sdlc:next
```

Queries your assigned Linear tickets, filters out blocked ones, and ranks by priority and cycle deadline. Presents the top 3 with a recommendation. When you pick one, it hands off to `/linear-sdlc:implement`.

### Implementing a ticket

```
/linear-sdlc:implement VER-42
```

Full lifecycle for a single ticket:

1. **Loads the ticket** from Linear (title, description, parent, spec)
2. **Pre-flight checks** — verifies the ticket isn't blocked, checks for existing branches, ensures clean working tree
3. **Sets status** to "In Progress" in Linear
4. **Creates a branch** (`feat/ver-42-short-description`)
5. **Plans** the implementation if the ticket is complex (>3 acceptance criteria)
6. **You code** with Claude's help
7. **Specialist self-review** — dispatches parallel sub-agents that review the diff:
   - **Testing specialist** — missing tests, weak assertions, untested paths
   - **Security specialist** — injection, hardcoded secrets, auth gaps (only when relevant code changed)
   - **Performance specialist** — N+1 queries, missing indexes, unbounded results (only when backend code changed)
   - **Code quality specialist** — dead code, DRY violations, naming issues
8. **Creates a PR** via `gh` with the ticket linked
9. **Sets status** to "In Review" in Linear
10. **Logs learnings and timeline** for future sessions

Critical findings from specialists must be fixed before the PR is created. Warnings are presented for your decision.

Before the PR is pushed, `/linear-sdlc:implement` also runs a **completeness check** — a placeholder/TODO scan across the diff and an acceptance-criteria walkthrough — so stray `TODO`s and unfinished criteria get surfaced. The check is advisory, not blocking: you decide whether to fix now, file a follow-up ticket, or accept as-is.

### Debugging a bug

```
/linear-sdlc:debug
```

Systematic bug investigation. The skill walks you through reproduce → identify component boundaries → instrument at each boundary → observe → hypothesize root cause → propose minimal fix. The core idea is **evidence before hypothesis**: gather data at the boundaries between components so you can pinpoint where wrong data first appears, rather than guessing from the crash site.

This is a soft discipline, not an iron law — if the root cause is obvious, the user can skip ahead. A learning is logged automatically when an investigation surfaces something non-obvious about the project.

### Saving and resuming work

Mid-session, save your progress:

```
/linear-sdlc:checkpoint
```

Captures git state, current ticket context, what you've done, and what's remaining. Writes a checkpoint file to `~/.linear-sdlc/projects/{slug}/checkpoints/`.

In a new session, resume:

```
/linear-sdlc:checkpoint resume
```

Loads the checkpoint, shows where you left off, offers to switch to the right branch and continue.

### Checking code health

```
/linear-sdlc:health
```

Auto-detects your project's quality tools (pytest, eslint, mypy, ruff, tsc, vitest, etc.), runs each one, and computes a weighted composite score:

- **Tests** (30%) — pass rate and coverage
- **Lint** (25%) — errors and warnings
- **Type checking** (25%) — type errors
- **Dead code** (20%) — unused code findings

Displays a dashboard with per-tool scores, composite score, trend vs previous run, and top 3 actionable recommendations.

## How It Works

### Linear MCP Server

All Linear operations (create issues, update status, search, set dependencies) go through the `@anthropic-ai/linear-mcp-server` MCP server. The plugin manifest declares it; Claude Code starts and supervises it. Your API key is read from your OS keychain via `userConfig`, never written to plaintext config files.

### Specialist Reviews

Before PR creation, `/linear-sdlc:implement` dispatches parallel sub-agents that independently review the `git diff` against specialist checklists (in `skills/implement/specialists/`). Each specialist returns structured findings classified as:

- **Critical** — must fix before PR (blocks merge)
- **Warning** — discuss with user (may need fixing)
- **Nit** — minor suggestion (skipped unless user wants to address)

Findings are deduplicated by file + line number across specialists.

### Knowledge Base

The knowledge system has two layers:

**Learnings (JSONL)** — Raw operational notes logged during skill execution. Fast, append-only. Each entry has a key, type, confidence score, and source (observed/inferred/documented). Confidence decays over time for observed/inferred entries (-1 point per 30 days).

**Wiki pages (Markdown)** — Synthesized knowledge created when 3+ learnings accumulate on a topic. Run `lsdlc-wiki-ingest` to generate wiki pages from learnings. Run `lsdlc-wiki-lint` to check for stale or inconsistent content.

Every skill loads relevant learnings at startup via the preamble, so context accumulates across sessions.

### Timeline

Every skill execution is logged to `timeline.jsonl` (start, completion, outcome). On session start, the preamble checks the timeline to show what happened last on the current branch — helping you pick up where you left off.

## Configuration

Config lives at `~/.linear-sdlc/config.json`. Inside any Claude Code session where the plugin is enabled, the helper scripts in `bin/` are on the Bash tool's `PATH` automatically — so you can call them as bare commands:

```bash
# Set your Linear team ID (set during onboarding)
lsdlc-config set linear_team_id VER

# Read a value
lsdlc-config get linear_team_id

# Show all config
lsdlc-config list
```

From a regular terminal outside Claude Code, you'd need the full path: `~/.claude/plugins/cache/<marketplace>/<version>/linear-sdlc/bin/lsdlc-config` (the path varies by Claude Code version and install scope).

## State Directory

All persistent state is stored locally at `~/.linear-sdlc/`:

```
~/.linear-sdlc/
├── config.json                    # User config (team ID, preferences)
├── .onboarding-complete           # First-run gate
└── projects/
    └── {slug}/                    # Per-project (derived from git remote)
        ├── learnings.jsonl        # Operational notes (append-only)
        ├── timeline.jsonl         # Skill execution history
        ├── {branch}-reviews.jsonl # Specialist review findings per branch
        ├── health-history.jsonl   # Health score trend data
        ├── wiki/                  # Synthesized knowledge pages
        │   ├── index.md           # Page catalog
        │   └── log.md             # Chronological activity log
        └── checkpoints/           # Saved session state
            └── {timestamp}-{title}.md
```

The project slug is derived from your git remote URL (e.g., `douglasswm-VerdictCouncil_Backend`), so each repo gets its own isolated state.

## Bin Scripts

| Script | Purpose |
|--------|---------|
| `lsdlc-slug` | Derive project slug and branch from git context |
| `lsdlc-config` | Read/write config.json (`get`, `set`, `list`) |
| `lsdlc-timeline-log` | Append skill events to timeline.jsonl |
| `lsdlc-learnings-log` | Append operational learnings to learnings.jsonl |
| `lsdlc-learnings-search` | Search and filter learnings with confidence decay |
| `lsdlc-wiki-ingest` | Synthesize learnings into wiki pages |
| `lsdlc-wiki-lint` | Check wiki for stale/inconsistent content |

## Rotating your Linear API key

```
/plugin uninstall linear-sdlc@linear-sdlc
/plugin install linear-sdlc@linear-sdlc
```

Re-installing prompts you for the API key again and writes the new value to your OS keychain. (A future Claude Code release may add a dedicated `/plugin reconfigure` command — until then, uninstall+reinstall is the supported flow.)

## License

MIT
