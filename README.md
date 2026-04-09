# linear-sdlc

A complete SDLC workflow for teams using Linear + Claude Code. Ticket-driven development with specialist code reviews, knowledge accumulation, and quality monitoring — distributed as a skills pack you clone, install, and own.

## Prerequisites

- **[Claude Code](https://docs.anthropic.com/en/docs/claude-code)** — the `claude` CLI
- **[Git](https://git-scm.com/)**
- **[Node.js](https://nodejs.org/) 18+** — required for built-in `fetch` (used by `bin/lsdlc-linear` and `./setup`)
- **[GitHub CLI (`gh`)](https://cli.github.com/)** — required by `/implement` for PR creation
- **Linear API key** — create one at [linear.app/settings/api](https://linear.app/settings/api)
- **Linear team ID** — find it in your Linear team URL; either the short key (e.g., `VER`) or the UUID form works

## Install — 30 seconds

### Step 1: Paste this into Claude Code

Open Claude Code and paste the prompt below verbatim. Claude runs the clone + setup for you, then writes a short `linear-sdlc` section into your `~/.claude/CLAUDE.md` so future sessions know the skills exist.

> Install linear-sdlc: run **`git clone --single-branch --depth 1 https://github.com/douglasswm/linear-sdlc.git ~/.claude/skills/linear-sdlc && cd ~/.claude/skills/linear-sdlc && ./setup --skip-api-key --skip-mcp-prompt`** then add a "linear-sdlc" section to `~/.claude/CLAUDE.md` that lists the available skills: /brainstorm, /create-tickets, /update-tickets, /next, /implement, /debug, /wiki, /checkpoint, /health, /upgrade, and notes that each loads project context (learnings, wiki, timeline) from `~/.linear-sdlc/projects/<slug>/` and `<repo>/.linear-sdlc/wiki/`. Then tell me to run `cd ~/.claude/skills/linear-sdlc && ./setup` once in a terminal to enter my Linear API key (from https://linear.app/settings/api) and team ID. Finally, ask me if I also want to install Linear's official HTTP MCP server for ad-hoc Linear queries (`claude mcp add --transport http linear https://mcp.linear.app/mcp`).

This runs the non-interactive parts of setup (skill symlinks, bin linking, directory creation) inside Claude Code. The secrets-handling step — API key + team ID — is left to you, in a real terminal, so your credentials never flow through the chat history.

### Step 2: Enter your Linear credentials (in a terminal)

```bash
cd ~/.claude/skills/linear-sdlc
./setup
```

`./setup` is idempotent. On this second run it will:

- Ask whether you want **short** skill names (`/brainstorm`) or **namespaced** ones (`/linear-sdlc-brainstorm`). Short is the default and remembered for next time.
- Prompt for your **Linear API key** and write it to `~/.linear-sdlc/env` (mode `0600`) — see [API key storage](#api-key-storage) below for alternatives.
- Prompt for your **Linear team ID**. Accepts either the short team key (e.g., `VER`) or the team UUID (e.g., `07877f05-4f32-42b4-a2df-9e1764316652`) — find it in your Linear team URL or settings.
- Print how to install the official Linear MCP server **separately** if you want it (we don't install it for you — see [Why we don't embed an MCP server](#why-we-dont-embed-an-mcp-server)).

You can re-run `./setup` any time. Existing values default to "keep". Switch naming with `./setup --prefix` / `./setup --no-prefix`.

### Manual install (alternative)

If you'd rather skip the one-prompt dance and do everything in a terminal:

```bash
git clone https://github.com/douglasswm/linear-sdlc.git ~/.claude/skills/linear-sdlc
cd ~/.claude/skills/linear-sdlc
./setup
```

Use `git@github.com:...` instead if you prefer SSH. Full clone (no `--depth 1`) is recommended if you plan to contribute or need history.

### Updating

linear-sdlc has **autoupdate** built in — every skill invocation silently checks whether a newer release is on GitHub, and when one exists the preamble prints an `UPDATE_AVAILABLE` banner. Claude then dispatches the `/upgrade` skill, which asks you (Yes / Always / Not now / Never ask again) and, on yes, runs the git upgrade for you. See [Autoupdate](#autoupdate) for the full behavior.

For teams that want fully hands-off updates, there's also an opt-in **team mode** (`./setup --team`) that installs a `SessionStart` hook so a background worker silently fetches the latest release on every Claude Code session start. See [Team mode](#team-mode-background-auto-update).

You can also upgrade manually at any time:

```bash
cd ~/.claude/skills/linear-sdlc
git pull
./setup
```

`./setup` re-links symlinks (idempotent) and respects your saved config.

### Uninstalling

```bash
# Remove skill symlinks — covers both install modes (/brainstorm and /linear-sdlc-brainstorm)
for _name in brainstorm next implement create-tickets update-tickets checkpoint debug health upgrade; do
  rm -rf ~/.claude/skills/"$_name" ~/.claude/skills/"linear-sdlc-$_name"
done
rm -f  ~/.local/bin/lsdlc-*
# Remove the checkout
rm -rf ~/.claude/skills/linear-sdlc
# Optional: wipe project state (learnings, timelines, checkpoints, wiki, update cache)
rm -rf ~/.linear-sdlc
```

### Migrating from v1 (the plugin era)

v1.0.x of linear-sdlc was packaged as a Claude Code plugin. v2 is a clean break — no plugin, no embedded MCP server, no marketplace install. To migrate:

1. **Uninstall the v1 plugin** in Claude Code:
   ```
   /plugin uninstall linear-sdlc@linear-sdlc
   ```
2. **Manually remove the OS keychain entry** for `linear_api_key`. On macOS, find it in Keychain Access by searching for "linear" or "claude-code"; on Linux, use your distro's secret-service tool; on Windows, Credential Manager. (Claude Code does not currently expose a keychain-cleanup command for plugin secrets.)
3. **Clone and run `./setup`** as above. Your `~/.linear-sdlc/projects/` state directory survives the migration intact — learnings, timelines, checkpoints, wiki pages, and per-branch review files all carry over.

## See it work

```
You:    I want to add rate limiting to our API endpoints.
You:    /brainstorm rate limiting

Claude: [searches Linear — finds VER-30 "Basic rate limiting" closed as
         won't-fix and VER-41 "Rate limiting v2" in Backlog]
        Two existing tickets found. Build on VER-41 or start fresh?
You:    Fresh — different scope.

Claude: This touches multiple subsystems (middleware, telemetry, ops).
        Switching to deep-design mode.
        [reads README.md, CLAUDE.md, globs specs/*.md for conventions]
        [proposes 3 approaches: inline middleware / sidecar / shared lib
         with a trade-off table — complexity, blast radius, migration]
        RECOMMENDATION: inline middleware — lowest blast radius, ships
        this week, upgradeable to a sidecar later if traffic demands.
        [walks through data model → API surface → failure modes → rollout,
         one section at a time, AskUserQuestion between each]
        [writes specs/rate-limiting.md]

You:    /create-tickets specs/rate-limiting.md

Claude: [parses the spec, proposes a breakdown]
        Parent: VER-101 "Rate limiting system"
        Children (blocking):
          VER-102 "Rate limiter middleware"      (Urgent, backend,security)
          VER-103 "Redis token bucket backend"   (High, backend) blocks 102
          VER-104 "Rate limit metrics + alerts"  (Medium, observability)
        Create all? [AskUserQuestion]
You:    Yes.
Claude: [creates via lsdlc-linear create-issue in a single bash call,
         captures IDs, adds blockedBy edges — one shell session so the
         parent/child references resolve]
        Created VER-101 and 3 sub-issues with dependencies.

You:    /next
Claude: [queries Linear for assigned unblocked tickets]
        In progress: none
        Candidates (top 3):
          1. VER-103  Redis token bucket backend    Urgent, Sprint 12 ← recommended
          2. VER-48   User profile page             High,   Sprint 12
          3. VER-50   Cleanup unused API routes     Medium, no cycle
        Why VER-103: highest priority, blocks VER-102, sprint deadline Apr 11.

You:    /implement VER-103

Claude: [loads full ticket via lsdlc-linear get-issue VER-103 — title,
         description, acceptance criteria, parent, blocking relations,
         labels. loads ~/.linear-sdlc/projects/.../learnings.jsonl for
         relevant prior context]
        Pre-flight: branch feature/ver-103-redis-token-bucket from main,
        set VER-103 → In Progress, restore last checkpoint if one exists.
        [implements the token bucket backend, 6 files, ~240 lines]
        Running specialist self-review in parallel:
          [testing]      2 warnings (edge cases for clock skew)
          [security]     1 critical (no bound on bucket size per IP) ← FIX
          [performance]  clean
          [code-quality] 1 nit (extract redis key builder)
        Critical finding must be fixed before PR. Fixing.
        [applies bound + adds regression test]
        Re-running security specialist... clean.
        [gh pr create with rich body referencing VER-103]
        PR #142 opened. VER-103 → In Review.
        WIKI: wrote tickets/VER-103.md + updated entities/rate-limiter.md
              and concepts/token-bucket.md (secret-scan: ok)

You:    /debug  the new rate-limit integration test fails under load

Claude: [reproduces: 10rps for 30s, flake rate 8%]
        Component boundaries identified: test harness → middleware →
        redis client → redis server.
        Instrumenting the middleware/redis boundary.
        [adds boundary logs, reruns]
        First divergence: redis INCR returns 1 when the bucket should
        be at 4. Root cause: test harness reuses a connection across
        buckets; TTL set-once pattern races on concurrent INCR.
        Minimal fix: SETNX the TTL on bucket creation instead of after.
        [applies fix, reruns test 20x — 0 failures]
        WIKI: wrote incidents/rate-limit-ttl-race.md, cross-linked to
              entities/rate-limiter.md (secret-scan: ok)

You:    /wiki query "how does our token bucket refill work"
Claude: [reads index.md → drills into concepts/token-bucket.md +
         entities/rate-limiter.md + the fresh incident page]
        Token bucket refills via redis INCR + SETNX on creation. The
        SETNX guard avoids the TTL race documented in
        [rate-limit-ttl-race](incidents/rate-limit-ttl-race.md).
        Save this answer as queries/how-token-bucket-refill-works.md?
You:    Yes.
Claude: Filed. Future /wiki query on this topic hits the cached answer.

You:    /health
Claude: [detects: pytest, ruff, mypy, vulture, lsdlc-wiki]
        TEST: pytest    151 passed
        LINT: ruff      clean
        TYPE: mypy      clean
        DEAD: vulture   3 unused helpers (nits)
        WIKI: lsdlc-wiki  42 pages, 0 orphans, 0 contradictions
        Score: 8.7 / 10  (+0.3 from last run 6 days ago)
        [logs trend to health-history.jsonl]

You:    /checkpoint
Claude: Captured branch, ticket, PR link, 2 open follow-up notes.
        Saved to ~/.linear-sdlc/projects/.../checkpoints/2026-04-09-rate-limiting.md
        Resume later with: /checkpoint resume
```

You said "rate limiting." The skills said "which conflict are we solving, what's already in Linear, which ticket should block which, which specialist will catch the IP-bucket bound you just forgot, what did we actually ship, and what did we learn that the next teammate needs to know." Eight commands, one ticket thread, no orphan branches — and the wiki is a few pages richer than it was this morning, committed on the same branch as the code it describes.

## The sprint

linear-sdlc is a **process**, not a bag of tools. The skills run in the order a Linear ticket lifecycle runs:

**Plan → Ticket → Pick → Build → Review → Reflect → Remember**

Each skill hands off to the next. `/brainstorm` writes a spec that `/create-tickets` reads, after reading the wiki for prior art. `/create-tickets` creates Linear issues that `/next` ranks. `/next` picks a ticket that `/implement` drives to PR. `/implement` runs parallel specialist reviewers and records findings in `<branch>-reviews.jsonl`, then auto-ingests the shipped work into the wiki (ticket synthesis page + fan-out updates to affected entity/concept pages). `/debug` uses that same per-branch state when a bug shows up mid-implementation, and auto-writes an `incidents/<slug>.md` page on a confirmed fix. `/checkpoint` freezes the whole thread so you can walk away and pick it up on a different machine. `/health` keeps a score-over-time that surfaces when quality is drifting, and includes a Wiki row so structural problems (contradictions, orphans, stale pages) are part of the same dashboard. `/wiki` is the explicit entry point for ingestion, querying, and lint — most of the time it runs in the background as part of `/implement` and `/debug`, but you invoke it directly to ask the wiki questions or ingest an external source. Nothing falls through the cracks because every step knows what came before it — the `~/.linear-sdlc/projects/<slug>/` state directory is the thread, and `<repo>/.linear-sdlc/wiki/` is the shared memory your teammates pull via git.

| Skill | Your specialist | What they do |
|---|---|---|
| `/brainstorm` | **Product Manager** | Start here for anything bigger than a single ticket. Searches Linear for duplicates first, runs a structured discussion, and for multi-subsystem features automatically switches into **deep-design mode** — codebase grounding, 2-3 approach trade-off table, section-by-section design walkthrough with per-section approval. Writes `specs/<slug>.md` with acceptance criteria, open questions, and scope boundaries. |
| `/create-tickets` | **Project Manager** | Reads a spec and breaks it into a parent Linear issue plus blocking sub-issues. Asks you to confirm the decomposition before anything is created. Runs the whole thing in a single shell session so parent/child references resolve — no orphan tickets. Uses `lsdlc-linear create-issue` + `add-relation` directly, so it works without the Linear MCP. |
| `/update-tickets` | **Ticket Archivist** | Refreshes existing Linear issue descriptions to match the structured issue-description template. Accepts a single issue ID, a parent ID (walks its children), or a spec path (finds every issue linking that spec). Detects already-on-template issues and skips them so re-runs are safe, reshapes the content against the template (preferring a linked spec, falling back to the existing description), and shows a per-issue diff for confirmation before calling `lsdlc-linear update-issue`. |
| `/next` | **Scrum Lead** | Three-second triage of your backlog. Queries Linear for assigned + unblocked tickets, filters out ones that already have a local branch, ranks by priority → cycle deadline → creation date, and presents the top 3 with a recommendation. Tells you when there's already something in flight before suggesting anything new. |
| `/implement` | **Staff Engineer** | Full ticket lifecycle, end to end. Loads the ticket + relevant learnings, pre-flight checks the working tree, sets Linear status to **In Progress**, creates the branch, codes with you, then runs **specialist self-review** in parallel sub-agents (testing / security / performance / code-quality). Critical findings block the PR. Opens the PR via `gh` with a body that references the ticket. Sets Linear status to **In Review**. |
| `/debug` | **Debugger** | Phase-1 diagnostic discipline: reproduce → identify component boundaries → instrument at the boundary → observe → hypothesize root cause → propose the minimal fix. Evidence before hypothesis. Soft rule, not iron law — User Sovereignty still applies, you can override at any point. |
| `/checkpoint` | **Session Memory** | Save and resume working state across Claude Code sessions. Captures git branch, current ticket, completed + remaining work, PR link, open notes. Writes to `~/.linear-sdlc/projects/<slug>/checkpoints/` as plain markdown — you can read them without any tooling. `/checkpoint resume` loads the most recent one and re-grounds the conversation. |
| `/health` | **Quality Lead** | Auto-detects your project's quality tools (pytest / jest / vitest, eslint / biome / ruff, tsc / mypy / pyright, vulture / knip), runs each, and computes a weighted composite score (tests 30%, lint 23%, types 23%, dead code 19%, wiki 5%). Logs the score to `health-history.jsonl` so you can see the trend across sprints. Flags regressions relative to the last run. |
| `/wiki` | **Knowledge Librarian** | Maintains the project's LLM Wiki — a persistent, LLM-authored knowledge base at `<repo>/.linear-sdlc/wiki/` that follows the three-layer llm_wiki pattern (raw sources → wiki → schema). Subcommands: `init` (scaffold once per repo), `ingest` (fan-out synthesis of a ticket/incident/source), `query` (search + answer + file back as `queries/<slug>.md`), `lint` (contradictions, orphans, stale pages, broken refs, data gaps), `sync` (resolve working-tree conflicts semantically), `sync-linear` (one-way push wiki pages → Linear Project Documents), `linear-setup` (interactive Linear Project picker), `ingest-source` (import external file), `migrate` (legacy home-dir wiki), `qmd-setup` / `qmd-refresh` (optional hybrid BM25 + vector search backend). `/implement` and `/debug` auto-call `ingest` on successful completion; every write passes a hard secret-scan gate before any file lands. See [LLM Wiki](#llm-wiki). |
| `/upgrade` | **Release Manager** | Dispatched automatically when the shared preamble detects a new linear-sdlc release on GitHub (or invokable directly). Presents a Yes / Always / Not now / Never dialog, runs `git fetch && git reset --hard origin/main && ./setup` on a clean working tree, and prints the new CHANGELOG entry. Refuses to clobber uncommitted local edits to the linear-sdlc checkout. See [Autoupdate](#autoupdate). |

Every skill logs its execution to `timeline.jsonl` so the next invocation of `/next`, `/implement`, or `/checkpoint` can surface *"what did I last do on this branch?"* without asking you. That's why the table of contents for any Linear ticket ends up matching your actual work history — the thread is the ticket, and the thread is the state directory.

**Why ticket-first, not branch-first?** Because a branch without a ticket is undocumented work. Every linear-sdlc skill assumes the ticket is the source of truth for *why* a change exists. If you start from `/next`, the ticket ID drives the branch name, the PR title, and the status transitions. If you start from `/implement VER-42`, same thing. You never have to remember to update Linear — the skills do it.

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
| `lsdlc-linear search-issues "<query>" [--team KEY\|UUID] [--limit N]` | Full-text search across the workspace |
| `lsdlc-linear list-assigned [--team KEY\|UUID] [--status "Todo,Backlog"] [--limit N]` | Issues assigned to you, filtered by state name |
| `lsdlc-linear get-issue VER-42` | Full ticket: title, description, parent, children, relations, labels, comments |
| `lsdlc-linear set-status VER-42 "In Progress"` | Move a ticket between workflow states (resolves the state name on the issue's team) |
| `lsdlc-linear create-issue --title "..." [--description "..."] [--team KEY\|UUID] [--priority N] [--labels l1,l2] [--parent VER-40]` | Create an issue, optionally with a parent and labels |
| `lsdlc-linear add-relation VER-42 blockedBy VER-41` | Add a `blocks` / `blockedBy` relation between two issues |

`--team` accepts either the short team key (e.g., `VER`) or the team UUID (e.g., `07877f05-4f32-42b4-a2df-9e1764316652`). The helper auto-detects the format and picks the right GraphQL filter — you can store whichever form is easier to copy from Linear in your `~/.linear-sdlc/config.json`.

Try it:

```bash
lsdlc-linear whoami
lsdlc-linear list-assigned --team VER --status "Todo,Backlog" --limit 5
# Or with a UUID:
lsdlc-linear list-assigned --team 07877f05-4f32-42b4-a2df-9e1764316652 --status "Todo" --limit 5
```

Pipe the output through `node -e` for inline parsing, or feed it through `jq` if you have it installed.

## API key storage

`./setup` writes your Linear API key to `~/.linear-sdlc/env` with mode `0600`:

```bash
# linear-sdlc env — parsed by bin/lsdlc-linear and the skill preamble.
export LINEAR_API_KEY='lin_api_...'
```

The skill preamble **parses** this file in pure shell — it never `.`-sources it. The env file lives in a user-writable directory, and `.`-sourcing would be an RCE surface if another process ever tampered with it. The preamble also refuses to read the file if it's group/other-writable or not owned by the current user. `bin/lsdlc-linear` does the equivalent parsing in pure JS (see its `resolveApiKey()` function).

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

If `LINEAR_API_KEY` is already in the environment when a skill runs, the preamble does NOT read `~/.linear-sdlc/env` — your shell-provided value wins.

Use `./setup --skip-api-key` to opt out of writing the env file entirely.

## State directory

Most persistent state lives at `~/.linear-sdlc/` (per-user, per-machine):

```
~/.linear-sdlc/
├── env                              # API key (mode 0600), if you used setup's prompt
├── config.json                      # team ID, skill_prefix, source_dir, wiki_scope, ...
├── last-update-check                # autoupdate cache: "<result> <local> <remote> <ts>"
├── update-snoozed                   # escalating "Not now" snooze: "<version> <level> <epoch>"
├── just-upgraded-from               # "<old> <new>" marker, shown once after /upgrade
├── .wiki-upgrade-pending            # one-time notice marker (wiki_scope auto-upgrade)
├── .wiki-scope-initialized          # setup-remember marker for wiki scope handling
├── .last-session-update             # team-mode throttle timestamp (1h window)
├── .session-update.lock             # team-mode PID lockfile (auto-clears stale PIDs)
├── analytics/
│   └── session-update.log           # team-mode worker decisions + git output
└── projects/
    └── {slug}/                      # per-project (slug derived from git remote)
        ├── learnings.jsonl          # PRIVATE operational notes (append-only, confidence decay)
        ├── timeline.jsonl           # skill execution history
        ├── {branch}-reviews.jsonl   # specialist review findings per branch
        ├── health-history.jsonl     # /health score trend
        ├── wiki/                    # (ONLY under wiki_scope=private — legacy mode)
        │   └── ...
        └── checkpoints/             # /checkpoint session state
```

**Wiki storage is different.** Under the default `wiki_scope=repo`, the
wiki lives in **the user's repo** at `<repo-root>/.linear-sdlc/wiki/` and
is committed via git so team members share it. Under `wiki_scope=private`
the wiki stays in `~/.linear-sdlc/projects/<slug>/wiki/` per-user. Under
`wiki_scope=off` the wiki is disabled entirely. See the [LLM Wiki](#llm-wiki)
section for the full model.

Override the `~/.linear-sdlc/` location with `LSDLC_STATE_DIR=/path/to/state`.

## LLM Wiki

linear-sdlc ships a **persistent, LLM-maintained wiki** that lives alongside
your code. It follows the llm_wiki pattern: instead of re-deriving knowledge
from raw sources on every query (RAG), the wiki is a compounding artifact —
`/implement` and `/debug` feed it automatically, and a schema file
(`<wiki>/CLAUDE.md`) teaches Claude how to maintain it.

### Layout

```
<your-repo>/.linear-sdlc/wiki/
├── CLAUDE.md       # schema — how Claude maintains this wiki (scoped by proximity)
├── index.md        # content catalog, grouped by category
├── log.md          # chronological append-only (git union merge for conflict-free appends)
├── .gitattributes  # log.md merge=union, index.md merge=union
├── entities/       # subsystems, modules, services (LLM-authored prose)
├── concepts/       # patterns, conventions, architecture decisions
├── tickets/        # synthesis of completed Linear tickets
├── incidents/      # root-caused bugs from /debug
├── queries/        # filed-back answers from /wiki query (explorations compound)
└── sources/        # RAW LAYER — immutable drop zone for external inputs
    ├── articles/     # articles, PDFs, blog posts
    ├── transcripts/  # meeting notes, customer calls
    ├── assets/       # images referenced from wiki pages
    └── legacy/       # populated by /wiki migrate
```

### Three layers

1. **Raw sources** (immutable) — code, Linear tickets, private learnings in
   `~/.linear-sdlc/projects/<slug>/learnings.jsonl`, and files dropped into
   `<wiki>/sources/`. The LLM reads; never modifies.
2. **The wiki** (LLM-owned) — entity/concept/ticket/incident/queries pages
   plus `index.md` and `log.md`. The LLM authors; you review diffs.
3. **The schema** (co-evolved) — `<wiki>/CLAUDE.md` tells the LLM how to
   maintain the wiki. Scoped to this subtree by directory proximity so it
   never collides with your repo's root `CLAUDE.md`.

### The `/wiki` skill

```
/wiki init                 Scaffold the wiki in the current repo (once)
/wiki ingest VER-42        Fan-out synthesis of a Linear ticket into wiki pages
/wiki query "how does auth work"  Search + synthesize + offer to file answer back
/wiki lint                 Structural report with suggested fixes
/wiki sync                 Resolve working-tree merge conflicts semantically
/wiki sync-linear          Push wiki pages to a Linear Project as Documents
/wiki linear-setup         Interactive: pick a Linear Project, enable sync
/wiki ingest-source PATH   Import an external file and synthesize it
/wiki migrate              Import legacy ~/.linear-sdlc home-dir wiki content
/wiki qmd-setup            Register the wiki as a qmd search collection (optional)
```

### Auto-ingest on `/implement` and `/debug`

With `wiki_auto_ingest=true` (default), `/implement` writes a
`tickets/<ID>.md` page plus updates to affected entity/concept pages on
every successful PR creation. With `wiki_auto_incident=true` (default),
`/debug` writes an `incidents/<slug>.md` page after a confirmed fix. All
writes go through a **hard secret-scan gate** (`lsdlc-wiki secret-scan`) and
are left in the working tree — never auto-committed. You review wiki edits
in the normal `git diff` before committing.

### Multi-team workflow

The wiki is committed alongside code. Two teammates can each auto-ingest
tickets the same day — `log.md` and `index.md` merge cleanly via the git
`merge=union` driver (configured automatically by `/wiki init`). Entity
page conflicts resolve via `/wiki sync`, which asks Claude to re-synthesize
conflicting sections from both sides.

### Optional: Linear Project Documents as a team-facing mirror

If your team uses Linear Projects for planning, run `/wiki linear-setup` to
pick a Project. `/wiki sync-linear` then pushes each wiki page to a Linear
**Document** under that Project (one-way, git → Linear). PMs and designers
who don't clone the repo get a read-only view of the wiki inside Linear's
UI, with Linear's search and notifications working over wiki content. The
sync is idempotent via caller-supplied UUIDs, secret-scanned before every
push, and never automatic by default (`wiki_linear_sync=false`).

### Optional: qmd for hybrid search

By default, `lsdlc-wiki search` uses grep (always available). If you want
BM25 + vector + LLM re-ranking at scale, install [qmd](https://github.com/tobi/qmd):

```bash
npm install -g @tobilu/qmd
/wiki qmd-setup
```

The search path auto-routes to qmd when the collection is registered and
healthy, and falls back to grep otherwise. For the smoothest integration,
register qmd as a Claude Code MCP server — Claude then calls `query`,
`get`, and `multi_get` as native tools:

```bash
claude mcp add qmd -- qmd mcp
```

### Privacy

The wiki is visible to everyone with read access to the repo. Never write
secrets, credentials, PII, customer names, or internal URLs. Defense in
depth:

- `lsdlc-wiki secret-scan` is a **hard gate** before every write (catches
  Stripe keys, AWS, GitHub tokens, JWTs, private PEMs, and common
  `api_key=`/`password=` assignments — see `bin/lsdlc-wiki`).
- The wiki `CLAUDE.md` schema tells the LLM to avoid writing sensitive
  material in the first place.
- Wiki edits are never auto-committed — you review the diff before pushing.
- `wiki_scope=private` is a first-class escape hatch for projects too
  sensitive to synthesize in a shared location at all.
- Linear sync is disabled by default; enabling it is an explicit opt-in.

## Bin scripts

| Script | Purpose |
|---|---|
| `lsdlc-slug` | Derive project slug + branch from git context |
| `lsdlc-config` | Read/write `config.json` (`get`, `set`, `unset`, `list`) |
| `lsdlc-timeline-log` | Append skill events to `timeline.jsonl` |
| `lsdlc-learnings-log` | Append operational learnings to `learnings.jsonl` |
| `lsdlc-learnings-search` | Search learnings with confidence decay and dedup |
| `lsdlc-wiki` | Unified wiki plumbing CLI: `path`, `init`, `log-append`, `index-upsert`, `lint`, `search`, `secret-scan`, `migrate`, `ingest-source`, `sync-linear`, `linear-map`, `qmd-setup`, `qmd-refresh`. The LLM does the synthesis; this CLI handles mechanism |
| `lsdlc-wiki-ingest` | **Deprecated shim** — forwards to `/wiki ingest`. Removed in a future release |
| `lsdlc-wiki-lint` | **Deprecated shim** — forwards to `lsdlc-wiki lint` |
| `lsdlc-update-check` | Silent release-check helper called by the shared preamble (see [Autoupdate](#autoupdate)) |
| `lsdlc-session-update` | Team-mode background auto-updater — forks on Claude Code session start, respects throttle/lock/config gates |
| `lsdlc-settings-hook` | Idempotent add/remove of entries in `~/.claude/settings.json` hooks; preserves foreign hooks on remove |
| `lsdlc-linear` | Direct Linear GraphQL helper (see [above](#the-lsdlc-linear-helper)) |

After `./setup`, all of these are on your `PATH` via `~/.local/bin/`. You can call them from any terminal — they're not Claude-specific.

## Model and effort defaults

Each skill is a single `SKILL.md` file with YAML frontmatter declaring which Claude model runs it and how much reasoning depth to apply. `./setup` symlinks each skill into `~/.claude/skills/` so Claude Code discovers it as a top-level command. The defaults are tuned for cost and latency on typical work, not worst case — escalate manually for genuinely architectural tasks.

| Skill | Model | Effort | Why |
|---|---|---|---|
| `/brainstorm` | Opus | Medium | Cross-domain synthesis for feature planning; medium is plenty for interactive Q&A |
| `/create-tickets` | Sonnet | Medium | Structured judgment over spec decomposition |
| `/update-tickets` | Sonnet | Medium | Reshaping existing issue descriptions against the template — same flavor of structured judgment as create-tickets |
| `/implement` | Sonnet | Medium | Most tickets are small; heavy reasoning happens inside the parallel specialist sub-agents |
| `/debug` | Sonnet | Medium | Diagnostic reasoning needs structure, not raw creativity |
| `/wiki` | Sonnet | Medium | LLM-authored prose for entity/concept pages + fan-out synthesis across 3-10 related pages per ingest |
| `/health` | Sonnet | Medium | Tool detection + composite scoring — structured, not creative |
| `/checkpoint` | Sonnet | Low | Mechanical state dump/restore |
| `/upgrade` | Sonnet | Medium | Mostly mechanical (git fetch + reset + setup), but needs judgment on the snooze/opt-out dialog and refuses to clobber uncommitted edits |
| `/next` | Haiku | Low | Query, rank, present — no synthesis |

Names above assume the default `--no-prefix` install. With `--prefix`, they become `/linear-sdlc-brainstorm`, etc.

If a skill feels underpowered for your workload, edit the `model:` and `effort:` lines in `skills/<skill>/SKILL.md` directly — symlinks pick up the change on the next session.

## How it works

### Direct GraphQL via `lsdlc-linear`

All Linear operations the skills perform — search, list, get, set status, create issues, create relations — go through `bin/lsdlc-linear`. The helper reads `LINEAR_API_KEY` from the environment (with the strict safety rule that the key never appears on argv or in error output) and POSTs to `https://api.linear.app/graphql` using Node 18+'s built-in `fetch`. No npm dependencies, no MCP server, no additional install steps.

If you've also installed Linear's official MCP server (recommended for ad-hoc queries — see [above](#why-we-dont-embed-an-mcp-server)), it coexists peacefully. Skills don't call it; you call it directly via Claude Code prompts.

### Specialist reviews

Before PR creation, `/implement` dispatches parallel sub-agents (via the `Agent` tool) that independently review the `git diff` against checklists in `skills/implement/specialists/`. Each specialist returns structured findings classified as **Critical** (must fix), **Warning** (discuss), or **Nit** (skip unless you want to address). Findings are deduplicated by file + line.

### Knowledge base — three layers

Per the [llm_wiki pattern](thoughts/llm_wiki.md), linear-sdlc's knowledge layer has three distinct surfaces:

1. **Learnings (JSONL, private per-user).** Raw operational notes appended by skills to `~/.linear-sdlc/projects/<slug>/learnings.jsonl`. Each entry has a key, type, confidence score, and source (observed / inferred / documented). Confidence decays -1 point per 30 days for observed/inferred entries. **Never auto-flow into the shared wiki** — they stay on the user's machine and inform LLM-curated synthesis, nothing more.

2. **The wiki (Markdown, LLM-owned, shared via git).** The persistent knowledge base at `<repo>/.linear-sdlc/wiki/` — committed alongside code so teammates share it via normal git. Subdirectories for `entities/`, `concepts/`, `tickets/`, `incidents/`, `queries/`, and a read-only `sources/` drop zone for external inputs (articles, transcripts, PDFs). `index.md` catalogs every page; `log.md` is a chronological append-only record with `.gitattributes` `merge=union` so concurrent teammate appends merge cleanly. The LLM writes, you review `git diff` before committing.

3. **The schema (Markdown, co-evolved).** `<repo>/.linear-sdlc/wiki/CLAUDE.md` tells Claude how to maintain this specific wiki — directory conventions, fan-out ingest workflow, contradiction-callout format, privacy rules. Scoped by directory proximity so it never collides with your repo's root `CLAUDE.md`. Scaffolded from `references/wiki-schema-template.md` by `/wiki init`; you and the LLM co-evolve it over time.

**Ingest is a fan-out, not a single-page write.** Per llm_wiki, a single source typically touches 10+ pages: the primary page (e.g. `tickets/VER-42.md`) plus updates to every affected entity/concept page, with contradiction callouts inserted wherever new claims disagree with old ones. `/implement` Step 9.4 and `/debug` Step 6.5 run this automatically on successful completion. Every draft goes through a hard `lsdlc-wiki secret-scan` gate before write — any hit aborts the entire ingest, no partial writes.

**Nothing auto-commits.** Wiki edits land in the working tree and show up in `git status` for your review before origin.

**Search scales from grep to hybrid.** By default `lsdlc-wiki search` uses grep with title-match and recency boosting. Install [qmd](https://github.com/tobi/qmd) and run `/wiki qmd-setup` to upgrade to BM25 + vector + LLM re-ranking, on-device. Registering qmd as a Claude Code MCP server makes it a native tool Claude calls directly. See [LLM Wiki](#llm-wiki) for the full model.

Every skill loads relevant learnings and prints the wiki status line (page count, contradictions, last log entry) at startup via the shared preamble, so context accumulates across sessions — and across teammates, once someone commits the wiki directory.

### Timeline

Every skill execution is logged to `timeline.jsonl` (start, completion, outcome). On session start, the preamble checks the timeline and surfaces what happened last on the current branch — helping you pick up where you left off.

## Autoupdate

linear-sdlc nags you when a newer release is available, with a dialog that respects your decision and doesn't interrupt the same way twice. The feature is a close port of gstack's autoupdate, adapted to linear-sdlc's shared-preamble architecture.

**How it fires.** Every skill's preamble runs `lsdlc-update-check` as its last step. The helper is silent on the happy path (cache hit, up to date, offline, opted out, snoozed). When a newer release exists, it prints a single `UPDATE_AVAILABLE <old> <new>` line to Claude's output, plus a one-line directive telling Claude to dispatch the `/upgrade` skill before resuming the current task. The update check itself never blocks a skill — it has a 5-second curl timeout and always exits 0.

**The dialog.** `/upgrade` runs an `AskUserQuestion` with four options:

- **Yes, upgrade now** — runs `git fetch && git reset --hard origin/main && ./setup --skip-api-key --skip-mcp-prompt -q` in the linear-sdlc checkout, prints the new `CHANGELOG.md` entry, and resumes the skill you were running.
- **Always keep me up to date** — sets `auto_upgrade: true` in `~/.linear-sdlc/config.json`, then upgrades. Future releases install silently without another dialog.
- **Not now** — writes an escalating snooze: 24 hours the first time, 48 hours the second, 7 days after that. A **new** remote release voids the old snooze, so you always hear about real news.
- **Never ask again** — sets `update_check: false`. No more checks, no more banners. Re-enable any time with `lsdlc-config unset update_check`.

**Safety rules.** `/upgrade` refuses to proceed if your linear-sdlc checkout has uncommitted changes (`git status` is non-empty), so your hacking-on-the-repo work is never silently clobbered. If you've made local edits, it tells you to commit/stash/discard first.

**Cache behavior.** The checker uses a split-TTL cache so it doesn't hit the network on every skill invocation:

| State | TTL | Why |
|---|---|---|
| `UP_TO_DATE` | 60 min | Detect new releases within an hour of release |
| `UPGRADE_AVAILABLE` | 12 h | Keep nagging without spamming the network once a release is known |

Network failures (curl timeout, DNS failure, HTTP error, invalid response body) are treated as `UP_TO_DATE` and **do not** write a cache entry, so the next invocation retries soon. If you're offline, you simply don't see the banner — no error, no delay.

**Opt out, turn back on, or force a check.**

```bash
# Disable all update checks
lsdlc-config set update_check false

# Re-enable
lsdlc-config unset update_check

# Enable silent auto-upgrade (no dialog, upgrades on the next skill run)
lsdlc-config set auto_upgrade true

# Disable silent auto-upgrade
lsdlc-config unset auto_upgrade

# Force an immediate check, ignoring cache and snooze
lsdlc-update-check --force
```

**Running `/upgrade` manually.** You can invoke it directly any time — it will re-run `lsdlc-update-check --force` and either upgrade, tell you you're already on the latest, or tell you the network check failed.

### Team mode (background auto-update)

For teams that want everyone pinned to the same linear-sdlc release without running `git pull` by hand, there's an opt-in **team mode** that installs a `SessionStart` hook in your Claude Code settings. At the start of every Claude Code session, a background worker silently fetches `origin/main`, fast-forwards if there's something new, and re-runs `./setup` — all in the background, never blocking session startup.

Enable it with:

```bash
cd ~/.claude/skills/linear-sdlc
./setup --team
```

That flag does three things:

1. Sets `auto_upgrade: true` and `team_mode: true` in `~/.linear-sdlc/config.json`.
2. Adds a `SessionStart` hook entry to `~/.claude/settings.json` pointing at `~/.local/bin/lsdlc-session-update`.
3. Leaves everything else in your settings file alone — including any `SessionStart` hooks other tools registered.

**What the background worker does.** On every session start, it:

- **Forks immediately and returns exit 0.** Session startup is never delayed by network latency.
- **Respects throttling.** Runs at most once per hour via `~/.linear-sdlc/.last-session-update`. Rapid session-open cycles don't thrash the network.
- **Respects locking.** A PID-based lockfile at `~/.linear-sdlc/.session-update.lock` prevents concurrent runs. Stale locks (dead PIDs) are auto-cleared.
- **Self-gates on config.** Checks `team_mode: true` + `update_check != false` every time. Disabling either one via `lsdlc-config` instantly neutralizes the hook, no JSON editing required.
- **Refuses to clobber uncommitted source changes.** If your linear-sdlc checkout has a dirty working tree, the worker logs "skip: uncommitted changes" and bails. Developer work always wins.
- **Logs everything** to `~/.linear-sdlc/analytics/session-update.log` — UTC-timestamped decisions, fetch output, HEAD transitions, setup output. You can audit exactly what the updater did.
- **Fires the `just-upgraded-from` marker** after a successful upgrade, so the next in-band skill invocation prints `JUST_UPGRADED <old> <new>` exactly once.

**Temporarily pause the updater without un-registering the hook:**

```bash
lsdlc-config set team_mode false       # or: set update_check false
# re-enable later:
lsdlc-config unset team_mode           # or: unset update_check
```

**Fully uninstall team mode:**

```bash
cd ~/.claude/skills/linear-sdlc
./setup --no-team
```

This unsets `team_mode` + `auto_upgrade` and removes the `SessionStart` hook entry. Foreign `SessionStart` hooks (ones other tools registered) are preserved.

**What's NOT shipped in v2.2.0** (may be revisited):

- No telemetry — the check never phones home beyond fetching the raw `VERSION` file from GitHub.
- No migration scripts — if a future release needs post-upgrade steps, the `/upgrade` skill will be extended to run them.
- Only git-install is supported — linear-sdlc has always been distributed as a git clone, so both `/upgrade` and the team-mode worker do `git fetch && git reset --hard origin/main && ./setup`. There's no tarball/vendored-install upgrade path.

## Hacking on linear-sdlc

The cloned checkout *is* the source of truth. Edit any `skills/*/SKILL.md`, `bin/*`, `references/*.md`, `references/preamble.sh`, or `templates/*` file and the change takes effect on Claude Code's next session — symlinks make this loopless.

**The shared preamble.** Every skill runs a tiny ~14-line bootstrap (resolve `LINEAR_SDLC_ROOT` from the skill's symlink) and then `.`-sources `references/preamble.sh`. That sourced file holds the parts every skill needs identically: the safe `LINEAR_API_KEY` loader, git branch + project slug detection, and session tracking via `lsdlc-timeline-log`. Edit `preamble.sh` once and every skill picks it up — the security-critical env loader can't drift between skills. Each `SKILL.md` still prints its own info lines (learnings count, wiki pages, last session, checkpoints, health history — whichever are relevant) after sourcing.

Adding a new skill:

1. Create `skills/your-skill/SKILL.md` with the standard YAML frontmatter (`name`, `description`, `model`, `effort`, `allowed-tools`).
2. Copy the ~14-line bootstrap block from `references/preamble.md` and change the `SKILL_NAME=` value.
3. Re-run `./setup` — the new skill gets symlinked automatically.

Editing an existing skill:

1. Edit `skills/<name>/SKILL.md` directly in the checkout.
2. No reinstall — Claude Code reads through the symlink on the next invocation.

Resetting state without touching keys:

```bash
mv ~/.linear-sdlc/projects ~/.linear-sdlc/projects.bak
```

## License

MIT
