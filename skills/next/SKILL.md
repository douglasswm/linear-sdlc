---
name: next
description: |
  Propose the next ticket to work on. Queries Linear for unblocked, unstarted
  tickets assigned to you, ranks by priority, and presents top 3 options.
  Use when: "what should I work on", "next ticket", "pick a task", "what's next".
model: haiku
effort: low
allowed-tools:
  - Bash
  - Read
  - AskUserQuestion
---

# /next — Pick Your Next Ticket

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
SKILL_NAME=next . "$LINEAR_SDLC_ROOT/references/preamble.sh"

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

## Step 1: Check for In-Progress Work

Before suggesting new work, check if there's already something in flight via the bundled `lsdlc-linear` helper:

```bash
TEAM=$(lsdlc-config get linear_team_id)
[ -n "$TEAM" ] && TEAM_FLAG="--team $TEAM" || TEAM_FLAG=""
lsdlc-linear list-assigned $TEAM_FLAG --status "In Progress" --limit 10
```

The output is JSON with `count` and `issues[]`. If any exist, present them first:

```
You have work in progress:
- VER-42: Auth middleware refactor (In Progress)

Continue this work, or pick something new?
```

If user wants to continue, suggest `/implement VER-42`.

## Step 2: Query Linear for Candidates

Fetch unstarted assigned tickets:

```bash
TEAM=$(lsdlc-config get linear_team_id)
[ -n "$TEAM" ] && TEAM_FLAG="--team $TEAM" || TEAM_FLAG=""
lsdlc-linear list-assigned $TEAM_FLAG --status "Todo,Backlog" --limit 20
```

Parse the JSON to extract identifier, title, priority, priorityLabel, state, labels, cycle, createdAt for ranking in Step 3:

```bash
lsdlc-linear list-assigned $TEAM_FLAG --status "Todo,Backlog" --limit 20 | node -e '
  const data = JSON.parse(require("fs").readFileSync(0, "utf8"));
  for (const i of data.issues) {
    const labels = (i.labels?.nodes || []).map(l => l.name).join(",");
    const cycle = i.cycle?.name || "";
    console.log([i.identifier, i.priorityLabel, i.title, labels, cycle].join("\t"));
  }
'
```

If user provides filters (project, cycle, label) in their prompt, narrow the results in your post-processing — Linear's filter syntax for these is more elaborate than the simple flags `lsdlc-linear` exposes.

If `lsdlc-linear list-assigned` returns non-zero (Linear unreachable, key
invalid), capture the failure and report BLOCKED with a recovery
suggestion:

```bash
_lsdlc_capture_error step-2 "linear-list-failed" "lsdlc-linear list-assigned failed during /next. Likely cause: <network|api-key|team-config>. User cannot pick a ticket until Linear is reachable."
```

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
lsdlc-timeline-log '{"skill":"next","event":"completed","branch":"'"$_BRANCH"'","outcome":"DONE","selected":"VER-45","session":"'"$_SESSION_ID"'"}' 2>/dev/null
```

```
STATUS: DONE
SUMMARY: Selected VER-45 (Add rate limiting to auth endpoints), starting /implement
```
