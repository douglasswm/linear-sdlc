---
name: create-tickets
description: |
  Convert a spec file into Linear issues with parent/child relationships and
  dependencies. Use when: "create tickets", "make issues", "spec to tickets",
  "break this down into tickets".
model: sonnet
effort: medium
argument-hint: "[path/to/spec.md]"
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
# Bootstrap: resolve LINEAR_SDLC_ROOT from this skill's symlink, then source
# the shared preamble (safe env loader + project detection + session tracking).
if [ -z "${LINEAR_SDLC_ROOT:-}" ]; then
  for _c in "$HOME/.claude/skills/brainstorm/SKILL.md" \
            "$HOME/.claude/skills/linear-sdlc-brainstorm/SKILL.md"; do
    if [ -L "$_c" ]; then
      LINEAR_SDLC_ROOT="$(cd "$(dirname "$(readlink "$_c")")/../.." && pwd)"
      break
    fi
  done
  [ -z "${LINEAR_SDLC_ROOT:-}" ] && LINEAR_SDLC_ROOT="$(lsdlc-config get source_dir 2>/dev/null || true)"
  export LINEAR_SDLC_ROOT
fi
SKILL_NAME=create-tickets . "$LINEAR_SDLC_ROOT/references/preamble.sh"

# Learnings (skill-specific display)
_LEARN_FILE="$_PROJ/learnings.jsonl"
if [ -f "$_LEARN_FILE" ]; then
  _LEARN_COUNT=$(wc -l < "$_LEARN_FILE" | tr -d ' ')
  echo "LEARNINGS: $_LEARN_COUNT entries"
  [ "$_LEARN_COUNT" -gt 0 ] && lsdlc-learnings-search --limit 3 2>/dev/null || true
else
  echo "LEARNINGS: 0"
fi

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

## Step 1b: Scope Check

Before planning the ticket breakdown, scan the spec for scope sprawl. If the work touches **many subsystems**, the right granularity may be multiple parent issues rather than one.

Heuristic:
1. Count distinct subsystems mentioned in the spec. A subsystem is any top-level `##`/`###` heading that names a service, module, or area (e.g. "Auth", "Billing", "Notifications"), plus any explicit service/module names in the technical approach.
2. If **≥ 3 distinct subsystems** are touched and the user hasn't already explicitly asked for one parent, ask:

```
**Re-ground:** This spec touches {N} subsystems: {comma-separated list}.

**Context:** Bundling all of this under one parent works if it ships together; splitting
into separate parents works better if each subsystem can ship independently.

**Options:**
1. **One parent with sub-issues** — recommended if everything ships as one release
2. **{N} separate parent issues** — recommended if each subsystem can ship independently
3. **Proceed as-is** — you decide the breakdown in the next step
```

Respect the user's choice and carry it into Step 2. If fewer than 3 subsystems, skip this check and go straight to Step 2.

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

Run **all of Step 4 inside a single Bash tool call** — bash variables (like `$PARENT_ID`, `$CHILD1_ID`) do NOT persist across separate Bash tool calls. If you split this into multiple tool calls, the parent/child references will be empty and you will create orphaned issues.

The pattern is: create parent → capture id → create each child with `--parent "$PARENT_ID"` → capture each child id → call `add-relation` for each blocking edge. All in one shell session.

Linear priority numbers: `0` = no priority, `1` = urgent, `2` = high, `3` = medium, `4` = low.

Template (substitute the actual title/description/priority/labels for each ticket from the breakdown approved in Step 3):

```bash
TEAM=$(lsdlc-config get linear_team_id)

# 1. Create the parent issue and capture its identifier.
#    Use a heredoc-into-variable for the description so the body can span multiple lines safely.
PARENT_DESC=$(cat <<'PARENT_DESC_EOF'
Implement rate limiting across API endpoints.

Spec: specs/rate-limiting.md
PARENT_DESC_EOF
)
PARENT_JSON=$(lsdlc-linear create-issue \
  --team "$TEAM" \
  --title "Rate Limiting System" \
  --description "$PARENT_DESC" \
  --priority 2 \
  --labels "backend,security")
PARENT_ID=$(printf '%s' "$PARENT_JSON" | node -e 'const j=JSON.parse(require("fs").readFileSync(0,"utf8")); process.stdout.write(j.issue.identifier)')
echo "Created parent: $PARENT_ID"

# 2. Create each sub-issue, capturing its identifier into a per-child variable.
#    Repeat this block for every sub-issue in the breakdown — one CHILDn pair per ticket.
CHILD1_JSON=$(lsdlc-linear create-issue \
  --team "$TEAM" \
  --title "Rate limiter middleware" \
  --description "Redis-based sliding window, configurable per-endpoint" \
  --priority 2 \
  --parent "$PARENT_ID" \
  --labels "backend")
CHILD1_ID=$(printf '%s' "$CHILD1_JSON" | node -e 'const j=JSON.parse(require("fs").readFileSync(0,"utf8")); process.stdout.write(j.issue.identifier)')
echo "Created child 1: $CHILD1_ID"

CHILD2_JSON=$(lsdlc-linear create-issue \
  --team "$TEAM" \
  --title "Apply rate limiting to auth endpoints" \
  --description "Login, register, password reset rate limited" \
  --priority 2 \
  --parent "$PARENT_ID" \
  --labels "backend,security")
CHILD2_ID=$(printf '%s' "$CHILD2_JSON" | node -e 'const j=JSON.parse(require("fs").readFileSync(0,"utf8")); process.stdout.write(j.issue.identifier)')
echo "Created child 2: $CHILD2_ID"

# 3. Wire blocking relationships from the dependency graph.
#    Pass blockedBy / blocks; lsdlc-linear translates to Linear's blocks relation type internally.
lsdlc-linear add-relation "$CHILD2_ID" blockedBy "$CHILD1_ID"
```

After running, Step 5's summary table can pull every identifier from the `echo` lines above (still in the same bash output).

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
lsdlc-timeline-log '{"skill":"create-tickets","event":"completed","branch":"'"$_BRANCH"'","outcome":"DONE","tickets_created":4,"parent":"VER-60","session":"'"$_SESSION_ID"'"}' 2>/dev/null
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
