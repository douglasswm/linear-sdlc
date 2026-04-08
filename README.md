# linear-sdlc

A complete SDLC workflow for teams using Linear + Claude Code. Ticket-driven development with specialist code reviews, knowledge accumulation, and quality monitoring.

## Prerequisites

Before installing, make sure you have:

- **Node.js** — Required for the Linear MCP server (`node --version` to check)
- **GitHub CLI** — Required for PR creation (`gh --version` to check, install with `brew install gh`)
- **Git** — Required for branch management
- **Linear API key** — Go to [Linear Settings → API → Personal API keys](https://linear.app/settings/api) and create one

## Installation

### Option 1: One-liner (paste into Claude Code)

```
Install linear-sdlc. First ask me for my Linear API key (from Linear Settings → API → Personal API keys) — note that the key will appear in our chat transcript. Then run: git clone --single-branch --depth 1 https://github.com/douglasswm/linear-sdlc.git ~/.claude/skills/linear-sdlc && cd ~/.claude/skills/linear-sdlc && LINEAR_API_KEY="<the key I gave you>" ./setup. (The LINEAR_API_KEY env var makes setup non-interactive — do NOT try to run ./setup without it, it will hang waiting on stdin.) After setup succeeds, add a "Linear SDLC" section to CLAUDE.md that says to use the Linear MCP server for all issue management, and lists the available skills: /brainstorm, /create-tickets, /next, /implement, /checkpoint, /health. Then ask me whether to also add linear-sdlc to the current project so teammates get it. Finally, remind me to restart Claude Code so the MCP server picks up the new key.
```

Claude will ask for your key, clone the repo, run setup non-interactively, update your `CLAUDE.md`, and remind you to restart.

**Privacy note:** because Claude needs the key to pass it to `setup`, the key will appear in the conversation's tool-call transcript. If that bothers you, use Option 2 (manual install) instead — `./setup` prompts for the key in your terminal and the key never touches the Claude conversation.

### Option 2: Manual install

```bash
# 1. Clone the repo
git clone --single-branch --depth 1 https://github.com/douglasswm/linear-sdlc.git ~/.claude/skills/linear-sdlc

# 2. Run setup (prompts for your Linear API key)
cd ~/.claude/skills/linear-sdlc && ./setup

# 3. Restart Claude Code (MCP servers load at startup)
```

### What setup does

1. **Checks dependencies** — Verifies `node`, `gh`, and `git` are installed
2. **Configures the Linear MCP server** — Merges `@anthropic-ai/linear-mcp-server` into `~/.claude/settings.json` with your API key
3. **Restricts file permissions on `settings.json`** — Sets mode `0600` (owner-only read/write) on POSIX systems so other local users and processes can't read your API key. On Windows under Git Bash / MSYS / Cygwin, also sets an explicit NTFS ACL via `icacls` granting full control to your user only. Silent no-op on filesystems that don't support either (e.g., WSL targeting a `/mnt/c` path — see the note below).
4. **Creates the state directory** — `~/.linear-sdlc/` for learnings, timeline, checkpoints
5. **Registers skills** — Creates symlinks in `~/.claude/skills/` so Claude Code discovers `/brainstorm`, `/create-tickets`, `/next`, `/implement`, `/checkpoint`, `/health`

> **Platform note:** On macOS, Linux, and WSL (Linux-native home), step 3 uses `chmod 600`. On Windows Git Bash / MSYS / Cygwin it also runs `icacls /inheritance:r /grant:r <you>:F`. If you run `setup` under WSL but target a Windows-side path (`/mnt/c/...`), neither path applies and your `settings.json` will keep its default NTFS ACL — use Git Bash or run `icacls` manually if you need it locked down.

### Verify installation

After restarting Claude Code, ask: **"List my Linear teams"**

If the MCP server is working, you'll see your Linear team(s) returned. If it fails, double-check your API key and restart Claude Code again.

### Team setup

When installing in a shared project, Claude will ask if you want to add linear-sdlc for teammates. If you say yes, it will:

- Add a "Linear SDLC" section to your project's `CLAUDE.md`
- Create `.claude/settings.json.example` with MCP config (placeholder API key)
- Commit the changes so teammates can install with the same one-liner

## Skills

Each skill is configured with an appropriate Claude model and effort level to balance reasoning depth with speed and cost.

| Skill | Description | Model | Effort |
|-------|-------------|-------|--------|
| `/brainstorm` | Plan new features, search for duplicates, write specs | Opus | Medium |
| `/create-tickets` | Convert spec files into Linear issues with dependencies | Sonnet | Medium |
| `/next` | Query Linear for unblocked tickets, recommend what to work on | Haiku | Low |
| `/implement` | Full lifecycle: ticket → branch → code → specialist review → PR | Sonnet | Medium |
| `/checkpoint` | Save/resume working state across sessions | Sonnet | Low |
| `/health` | Code quality dashboard with composite scoring | Sonnet | Medium |

**Why different models?** Defaults are tuned for cost and latency on typical tickets, not worst-case complexity:

- **`/brainstorm`** uses **Opus** because feature planning benefits from cross-domain synthesis and catching subtle product nuance. Medium effort is plenty for interactive Q&A — high effort is wasted when the human drives the pace.
- **`/implement`** uses **Sonnet/Medium** because most tickets are small (one or two files, a handful of acceptance criteria). The heavy reasoning during specialist self-review runs in parallel sub-agents that can decide their own depth. For a genuinely architectural ticket, either run `/brainstorm` first to front-load the thinking, or manually bump `implement/SKILL.md` to `opus`/`high` for that session.
- **`/create-tickets`** and **`/health`** use **Sonnet/Medium** — structured work with enough judgment (dependency inference, scoring) to benefit from medium effort.
- **`/next`** uses **Haiku/Low** — it's a query, a rank, and a presentation. Haiku is faster and sufficient.
- **`/checkpoint`** uses **Sonnet/Low** — mostly mechanical state dump/restore.

If a skill feels underpowered for your work, override it locally — just edit the `model:` and `effort:` lines in that skill's `SKILL.md`. Edits in `~/.claude/skills/linear-sdlc/` will conflict on the next `git pull` if upstream also touches the file, so fork the repo or keep a patch if you rely on a permanent override.

## Usage

### Planning a new feature

Start with `/brainstorm` to explore the idea, search Linear for existing related tickets, and write a spec file:

```
/brainstorm rate limiting
```

This walks you through a structured discussion (problem, impact, solution shape, scope, technical approach) and writes a spec to `specs/rate-limiting.md`.

When the spec is ready, convert it to Linear tickets:

```
/create-tickets specs/rate-limiting.md
```

This creates a parent issue and sub-issues in Linear with proper dependencies, priorities, and labels. You confirm the breakdown before anything is created.

### Picking what to work on

```
/next
```

Queries your assigned Linear tickets, filters out blocked ones, and ranks by priority and cycle deadline. Presents the top 3 with a recommendation. When you pick one, it hands off to `/implement`.

### Implementing a ticket

```
/implement VER-42
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

### Saving and resuming work

Mid-session, save your progress:

```
/checkpoint
```

Captures git state, current ticket context, what you've done, and what's remaining. Writes a checkpoint file to `~/.linear-sdlc/projects/{slug}/checkpoints/`.

In a new session, resume:

```
/checkpoint resume
```

Loads the checkpoint, shows where you left off, offers to switch to the right branch and continue.

### Checking code health

```
/health
```

Auto-detects your project's quality tools (pytest, eslint, mypy, ruff, tsc, vitest, etc.), runs each one, and computes a weighted composite score:

- **Tests** (30%) — pass rate and coverage
- **Lint** (25%) — errors and warnings
- **Type checking** (25%) — type errors
- **Dead code** (20%) — unused code findings

Displays a dashboard with per-tool scores, composite score, trend vs previous run, and top 3 actionable recommendations.

## How It Works

### Linear MCP Server

All Linear operations (create issues, update status, search, set dependencies) go through the `@anthropic-ai/linear-mcp-server` MCP server. This is configured automatically during setup and runs as part of Claude Code's MCP infrastructure — no separate process to manage.

### Specialist Reviews

Before PR creation, `/implement` dispatches parallel sub-agents that independently review the `git diff` against specialist checklists (in `implement/specialists/`). Each specialist returns structured findings classified as:

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

Config lives at `~/.linear-sdlc/config.json`. Managed with the config script:

```bash
# Set your Linear team ID (set during onboarding)
~/.claude/skills/linear-sdlc/bin/lsdlc-config set linear_team_id VER

# Read a value
~/.claude/skills/linear-sdlc/bin/lsdlc-config get linear_team_id

# Show all config
~/.claude/skills/linear-sdlc/bin/lsdlc-config list
```

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

## Updating

```bash
cd ~/.claude/skills/linear-sdlc && git pull
```

No build step required — changes take effect on the next Claude Code session.

### Rotating your Linear API key

Re-run `./setup` at any time. It detects the existing key, shows a masked preview, and asks whether to replace it:

```bash
cd ~/.claude/skills/linear-sdlc && ./setup
```

For non-interactive updates (e.g., CI), pass the new key via env var — it skips the prompt:

```bash
LINEAR_API_KEY=lin_api_xxx ./setup
```

Restart Claude Code after updating the key so the MCP server picks it up.

## License

MIT
