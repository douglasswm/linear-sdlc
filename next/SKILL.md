---
name: next
description: |
  Propose the next ticket to work on. Queries Linear for unblocked, unstarted
  tickets assigned to you, ranks by priority, and presents top 3 options.
  Use when: "what should I work on", "next ticket", "pick a task", "what's next".
allowed-tools:
  - Bash
  - Read
  - AskUserQuestion
---

# /next — Pick Your Next Ticket

## Preamble

Run this first:

```bash
_BRANCH=$(git branch --show-current 2>/dev/null || echo "unknown")
_SLUG=$(~/.claude/skills/linear-sdlc/bin/lsdlc-slug 2>/dev/null | grep '^SLUG=' | cut -d= -f2 || basename "$(git rev-parse --show-toplevel 2>/dev/null || pwd)")
_PROJ="${HOME}/.linear-sdlc/projects/${_SLUG}"
mkdir -p "$_PROJ/checkpoints" "$_PROJ/wiki"

echo "BRANCH: $_BRANCH"
echo "PROJECT: $_SLUG"

_LEARN_FILE="$_PROJ/learnings.jsonl"
if [ -f "$_LEARN_FILE" ]; then
  _LEARN_COUNT=$(wc -l < "$_LEARN_FILE" | tr -d ' ')
  echo "LEARNINGS: $_LEARN_COUNT entries"
  [ "$_LEARN_COUNT" -gt 0 ] && ~/.claude/skills/linear-sdlc/bin/lsdlc-learnings-search --limit 3 2>/dev/null || true
else
  echo "LEARNINGS: 0"
fi

_SESSION_ID="$$-$(date +%s)"
~/.claude/skills/linear-sdlc/bin/lsdlc-timeline-log '{"skill":"next","event":"started","branch":"'"$_BRANCH"'","session":"'"$_SESSION_ID"'"}' 2>/dev/null &

echo "---"
```

## Step 1: Check for In-Progress Work

Before suggesting new work, check if there's already something in flight:

1. Use Linear MCP to search for tickets assigned to "me" with status "In Progress"
2. If any exist, present them first:
   ```
   You have work in progress:
   - VER-42: Auth middleware refactor (In Progress, branch: feat/ver-42-auth-refactor)

   Continue this work, or pick something new?
   ```
3. If user wants to continue, suggest `/implement VER-42`

## Step 2: Query Linear for Candidates

Use the Linear MCP server to fetch tickets:

1. **Get my assigned tickets** with status: Todo, Backlog
2. **Get team ID** from config: `~/.claude/skills/linear-sdlc/bin/lsdlc-config get linear_team_id`
3. If user provides filters (project, cycle, label), apply them

## Step 3: Filter and Rank

Filter out tickets that:
- Have unresolved blocking dependencies (other tickets that must be Done first)
- Already have a local branch (already started — check with `git branch --list`)

Rank remaining tickets by:
1. **Priority** — Urgent > High > Medium > Low > No priority
2. **Cycle deadline** — Tickets in a cycle with closer deadline rank higher
3. **Creation date** — Older tickets break ties (FIFO)

## Step 4: Present Top 3

Display the top 3 candidates:

```
## Recommended Next Tickets

| # | Ticket | Title | Priority | Cycle | Labels |
|---|--------|-------|----------|-------|--------|
| 1 | VER-45 | Add rate limiting to auth endpoints | Urgent | Sprint 12 (Apr 11) | backend, security |
| 2 | VER-48 | User profile page | High | Sprint 12 (Apr 11) | frontend |
| 3 | VER-50 | Cleanup unused API routes | Medium | — | backend, tech-debt |
```

Use AskUserQuestion:

```
**Re-ground:** Looking for your next ticket to implement.

**Options:**
1. **VER-45** — Add rate limiting to auth endpoints (Urgent, Sprint 12) — recommended
2. **VER-48** — User profile page (High, Sprint 12)
3. **VER-50** — Cleanup unused API routes (Medium, no cycle)
4. **Show more** — See additional candidates
5. **None of these** — I'll pick my own

**Recommendation:** VER-45 — highest priority and in the current sprint.
```

## Step 5: Act on Selection

When the user picks a ticket:
- Announce: "Starting VER-45. Running `/implement VER-45`."
- Invoke the `/implement` skill with the selected ticket ID

If "Show more": fetch and display the next 5 candidates.
If "None of these": ask what they'd like to work on instead.

## Step 6: Wrap Up

```bash
~/.claude/skills/linear-sdlc/bin/lsdlc-timeline-log '{"skill":"next","event":"completed","branch":"'"$_BRANCH"'","outcome":"DONE","selected":"VER-45","session":"'"$_SESSION_ID"'"}' 2>/dev/null
```

```
STATUS: DONE
SUMMARY: Selected VER-45 (Add rate limiting to auth endpoints), starting /implement
```
