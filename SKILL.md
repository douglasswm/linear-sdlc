---
name: linear-sdlc
description: |
  Linear SDLC workflow for Claude Code. Provides ticket-driven development
  with brainstorming, ticket creation, implementation, specialist reviews,
  checkpoints, and health monitoring — all powered by the Linear MCP server.
allowed-tools:
  - Bash
  - Read
  - Glob
  - Grep
  - AskUserQuestion
---

# linear-sdlc — Session Start

## Preamble

Run this first to detect project context:

```bash
# Detect project
_BRANCH=$(git branch --show-current 2>/dev/null || echo "unknown")
_SLUG=$(~/.claude/skills/linear-sdlc/bin/lsdlc-slug 2>/dev/null | grep '^SLUG=' | cut -d= -f2 || basename "$(git rev-parse --show-toplevel 2>/dev/null || pwd)")
_PROJ="${HOME}/.linear-sdlc/projects/${_SLUG}"
mkdir -p "$_PROJ/checkpoints" "$_PROJ/wiki"

echo "BRANCH: $_BRANCH"
echo "PROJECT: $_SLUG"

# Load learnings
_LEARN_FILE="$_PROJ/learnings.jsonl"
if [ -f "$_LEARN_FILE" ]; then
  _LEARN_COUNT=$(wc -l < "$_LEARN_FILE" | tr -d ' ')
  echo "LEARNINGS: $_LEARN_COUNT entries"
  [ "$_LEARN_COUNT" -gt 0 ] && ~/.claude/skills/linear-sdlc/bin/lsdlc-learnings-search --limit 3 2>/dev/null || true
else
  echo "LEARNINGS: 0"
fi

# Wiki status
_WIKI_PAGES=$(find "$_PROJ/wiki" -name "*.md" ! -name "index.md" ! -name "log.md" 2>/dev/null | wc -l | tr -d ' ')
echo "WIKI: $_WIKI_PAGES pages"

# Context recovery
if [ -f "$_PROJ/timeline.jsonl" ]; then
  _LAST=$(grep "\"branch\":\"${_BRANCH}\"" "$_PROJ/timeline.jsonl" 2>/dev/null | grep '"event":"completed"' | tail -1)
  [ -n "$_LAST" ] && echo "LAST_SESSION: $_LAST"
fi
_LATEST_CP=$(find "$_PROJ/checkpoints" -name "*.md" -type f 2>/dev/null | xargs ls -1t 2>/dev/null | head -1)
[ -n "$_LATEST_CP" ] && echo "LATEST_CHECKPOINT: $_LATEST_CP"

echo "---"
```

## Onboarding

If `~/.linear-sdlc/.onboarding-complete` does NOT exist, run onboarding:

1. Ask the user for their Linear team identifier (e.g., "VER")
2. Store it: `~/.claude/skills/linear-sdlc/bin/lsdlc-config set linear_team_id <value>`
3. Verify the Linear MCP server is working by listing teams
4. If MCP fails, tell the user to restart Claude Code (MCP servers load at startup)
5. Create `~/.linear-sdlc/.onboarding-complete`

## Skill Routing

When the user's request matches one of these patterns, invoke the corresponding skill:

| User says | Skill |
|-----------|-------|
| "brainstorm", "plan a feature", "new feature idea", "explore an idea" | `/brainstorm` |
| "create tickets", "make issues", "spec to tickets", "break this down" | `/create-tickets` |
| "what should I work on", "next ticket", "pick a task", "what's next" | `/next` |
| "implement", "work on VER-", "start ticket", "build VER-" | `/implement` |
| "checkpoint", "save progress", "where was I", "resume" | `/checkpoint` |
| "health", "code quality", "run checks", "how healthy" | `/health` |

When routing, announce the skill you're invoking: "Using `/implement` to work on VER-42."

## Available Skills

- **`/brainstorm`** — Plan new features, search for duplicates, write specs
- **`/create-tickets`** — Convert spec files into Linear issues with dependencies
- **`/next`** — Query Linear for unblocked tickets, recommend what to work on
- **`/implement`** — Full lifecycle: load ticket → branch → code → specialist review → PR
- **`/checkpoint`** — Save/resume working state across sessions
- **`/health`** — Code quality dashboard with composite scoring

## Operational Self-Improvement

When you discover something non-obvious about the project during any skill execution, log it:

```bash
~/.claude/skills/linear-sdlc/bin/lsdlc-learnings-log '{"skill":"SKILL","type":"TYPE","key":"KEY","insight":"INSIGHT","confidence":N,"source":"observed"}'
```

Types: `operational`, `pitfall`, `convention`, `dependency`, `architecture`.
Sources: `observed` (saw it happen), `inferred` (deduced), `documented` (read in docs).

## AskUserQuestion Format

Follow the format in `references/ask-user-format.md`:
- Re-ground (where we are)
- Context (why this matters)
- Options (2-4, with recommendation)

## Completion Status

End every skill with a status report per `references/completion-status.md`:
DONE | DONE_WITH_CONCERNS | BLOCKED | NEEDS_CONTEXT
