---
name: create-tickets
description: |
  Convert a spec file into Linear issues with parent/child relationships and
  dependencies. Use when: "create tickets", "make issues", "spec to tickets",
  "break this down into tickets".
model: sonnet
effort: medium
allowed-tools:
  - Bash
  - Read
  - Glob
  - AskUserQuestion
---

# /create-tickets — Spec to Linear Issues

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
~/.claude/skills/linear-sdlc/bin/lsdlc-timeline-log '{"skill":"create-tickets","event":"started","branch":"'"$_BRANCH"'","session":"'"$_SESSION_ID"'"}' 2>/dev/null &

echo "---"
```

## Step 1: Load the Spec

The user invokes this as `/create-tickets specs/rate-limiting.md` or `/create-tickets`.

If a spec file path is provided, read it.

If no path is provided:
1. Look for spec files: `ls specs/*.md 2>/dev/null`
2. If specs exist, present them and ask which to use
3. If no specs exist, suggest running `/brainstorm` first

Read and parse the spec file. Extract:
- **Feature title** (from the `# Feature:` heading)
- **Problem statement** (from the Problem section)
- **User stories** (from the User Stories section)
- **Technical approach** (from the Technical Approach section)
- **Acceptance criteria** (from the Acceptance Criteria section)

## Step 2: Plan the Ticket Breakdown

Analyze the spec and propose a ticket structure:

1. **Parent issue** — The feature/epic level ticket
2. **Sub-issues** — Individual implementable tickets
3. **Dependencies** — Which sub-issues must be completed before others

Guidelines for breakdown:
- Each sub-issue should be completable in 1-3 sessions
- Each sub-issue should have clear acceptance criteria
- Identify the critical path (what must be done first)
- Group related work (don't split a natural unit across tickets)

## Step 3: Confirm with User

Present the proposed breakdown:

```
## Ticket Breakdown: Rate Limiting

### Parent Issue
**Rate Limiting System** — Implement rate limiting across API endpoints

### Sub-Issues

| # | Title | Priority | Dependencies | Acceptance Criteria |
|---|-------|----------|-------------|---------------------|
| 1 | Rate limiter middleware | High | None | Redis-based sliding window, configurable per-endpoint |
| 2 | Apply rate limiting to auth endpoints | High | #1 | Login, register, password reset rate limited |
| 3 | Rate limit response headers | Medium | #1 | X-RateLimit-* headers on all responses |
| 4 | Rate limiting dashboard | Low | #1, #2 | Admin view of rate limit stats |
```

Use AskUserQuestion:
```
**Re-ground:** Ready to create 4 tickets in Linear (1 parent + 3 sub-issues).

**Options:**
1. **Create all** — Create these tickets as shown (recommended)
2. **Adjust** — Modify the breakdown before creating
3. **Cancel** — Don't create tickets yet

**Recommendation:** Create all — we can always adjust tickets in Linear after creation.
```

## Step 4: Create in Linear

Get the team ID: `~/.claude/skills/linear-sdlc/bin/lsdlc-config get linear_team_id`

For each ticket, use the Linear MCP server:

1. **Create parent issue:**
   - Title: Feature title from spec
   - Description: Problem statement + link to spec file
   - Priority: Based on spec urgency
   - Labels: Derived from technical approach (e.g., "backend", "frontend", "security")

2. **Create sub-issues** (in dependency order):
   - Title: Sub-issue title
   - Description: Acceptance criteria + relevant technical approach details
   - Priority: As specified in breakdown
   - Parent: Link to parent issue created in step 1
   - Labels: Inherited from parent + specific labels

3. **Set dependencies** between sub-issues:
   - Use Linear's "blocking/blocked by" relationships
   - Follow the dependency graph from Step 2

## Step 5: Summary

Present the created tickets:

```
## Created Tickets

| Ticket | Title | Priority | Status | Dependencies |
|--------|-------|----------|--------|-------------|
| VER-60 | Rate Limiting System (parent) | High | Backlog | — |
| VER-61 | Rate limiter middleware | High | Todo | — |
| VER-62 | Apply rate limiting to auth endpoints | High | Todo | Blocked by VER-61 |
| VER-63 | Rate limit response headers | Medium | Todo | Blocked by VER-61 |
| VER-64 | Rate limiting dashboard | Low | Backlog | Blocked by VER-61, VER-62 |

**Spec file:** `specs/rate-limiting.md`
**Start working:** Run `/next` to pick a ticket, or `/implement VER-61` to start with the foundation.
```

## Step 6: Wrap Up

```bash
~/.claude/skills/linear-sdlc/bin/lsdlc-timeline-log '{"skill":"create-tickets","event":"completed","branch":"'"$_BRANCH"'","outcome":"DONE","tickets_created":4,"parent":"VER-60","session":"'"$_SESSION_ID"'"}' 2>/dev/null
```

```
STATUS: DONE
SUMMARY: Created 4 Linear tickets (VER-60 through VER-64) from specs/rate-limiting.md
```

## Important Rules

1. **Always confirm before creating.** Never create tickets without user approval of the breakdown.
2. **Set dependencies accurately.** Wrong dependencies cause confusion when `/next` recommends tickets.
3. **Keep descriptions actionable.** Each ticket's description should have enough context to implement without reading the full spec.
4. **Link back to the spec.** Include the spec file path in the parent ticket description.
