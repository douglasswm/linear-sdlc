---
name: checkpoint
description: |
  Save and resume working state across sessions. Captures git state, conversation
  context, current Linear ticket, and remaining work.
  Use when: "checkpoint", "save progress", "where was I", "resume".
model: sonnet
effort: low
allowed-tools:
  - Bash
  - Read
  - Write
  - Glob
  - AskUserQuestion
---

# /checkpoint — Save and Resume Working State

## Preamble

Run this first:

```bash
_BRANCH=$(git branch --show-current 2>/dev/null || echo "unknown")
_SLUG=$(~/.claude/skills/linear-sdlc/bin/lsdlc-slug 2>/dev/null | grep '^SLUG=' | cut -d= -f2 || basename "$(git rev-parse --show-toplevel 2>/dev/null || pwd)")
_PROJ="${HOME}/.linear-sdlc/projects/${_SLUG}"
mkdir -p "$_PROJ/checkpoints" "$_PROJ/wiki"

echo "BRANCH: $_BRANCH"
echo "PROJECT: $_SLUG"

# List existing checkpoints
_CP_COUNT=$(find "$_PROJ/checkpoints" -name "*.md" -type f 2>/dev/null | wc -l | tr -d ' ')
echo "CHECKPOINTS: $_CP_COUNT saved"
if [ "$_CP_COUNT" -gt 0 ]; then
  echo "LATEST:"
  find "$_PROJ/checkpoints" -name "*.md" -type f 2>/dev/null | xargs ls -1t 2>/dev/null | head -3
fi

_SESSION_ID="$$-$(date +%s)"
~/.claude/skills/linear-sdlc/bin/lsdlc-timeline-log '{"skill":"checkpoint","event":"started","branch":"'"$_BRANCH"'","session":"'"$_SESSION_ID"'"}' 2>/dev/null &

echo "---"
```

## Detect Mode

Determine if the user wants to **save** or **resume**:

- "save", "checkpoint", "save progress" → **Save mode**
- "resume", "where was I", "pick up", "continue" → **Resume mode**
- No clear intent → Ask:
  ```
  **Re-ground:** Checkpoint skill invoked.

  **Options:**
  1. **Save** — Capture current state for later (recommended if you're about to stop)
  2. **Resume** — Load a previous checkpoint and continue working
  3. **List** — See all saved checkpoints
  ```

---

## Save Mode

### Step 1: Gather State

Collect current working context:

```bash
# Git state
echo "=== GIT STATE ==="
git branch --show-current
git log --oneline -5
git status --short
git diff --stat

# Current ticket (if on a feature branch)
echo "=== BRANCH ==="
echo "$_BRANCH"
```

### Step 2: Capture Context

Ask the user (or infer from conversation):
1. **What ticket are you working on?** (e.g., VER-42)
2. **What have you accomplished so far?** (summary of completed work)
3. **What's remaining?** (next steps, open questions)
4. **Any blockers or concerns?** (things to remember)

If there's an active `/implement` session, extract this from the conversation context automatically.

### Step 3: Write Checkpoint

Generate a timestamp and title:
```bash
TIMESTAMP=$(date +%Y%m%d-%H%M%S)
# Title from ticket or user-provided
TITLE="ver-42-auth-refactor"
```

Write the checkpoint file:

```markdown
---
timestamp: 2026-04-07T15:30:00Z
branch: feat/ver-42-auth-refactor
ticket: VER-42
ticket_title: Refactor auth middleware
ticket_status: In Progress
---

# Checkpoint: VER-42 — Refactor auth middleware

## Completed
- Extracted auth middleware from monolithic handler
- Created new auth/middleware.py with JWT validation
- Updated all route handlers to use new middleware
- Added unit tests for token validation

## Remaining
- [ ] Integration tests for auth flow
- [ ] Update API docs
- [ ] Specialist review
- [ ] Create PR

## Open Questions
- Should we support refresh tokens in this ticket or defer?

## Git State
- Branch: feat/ver-42-auth-refactor
- Last commit: abc1234 "refactor: extract auth middleware"
- Uncommitted changes: 2 files modified

## Key Decisions Made
- Using PyJWT instead of python-jose (simpler API, fewer deps)
- Token expiry set to 1 hour (was 24 hours)
```

Save to: `$_PROJ/checkpoints/${TIMESTAMP}-${TITLE}.md`

### Step 4: Confirm

```
STATUS: DONE
SUMMARY: Checkpoint saved to checkpoints/20260407-153000-ver-42-auth-refactor.md
         Resume with: /checkpoint resume
```

---

## Resume Mode

### Step 1: Find Checkpoints

```bash
# List checkpoints, newest first
find "$_PROJ/checkpoints" -name "*.md" -type f | xargs ls -1t 2>/dev/null
```

### Step 2: Select Checkpoint

If only one checkpoint exists, load it automatically.

If multiple exist, present the most recent 5:
```
## Saved Checkpoints

| # | Date | Ticket | Branch | Title |
|---|------|--------|--------|-------|
| 1 | Apr 7 15:30 | VER-42 | feat/ver-42-auth-refactor | Auth middleware refactor |
| 2 | Apr 5 10:15 | VER-40 | feat/ver-40-auth-overhaul | Auth system overhaul |
| 3 | Apr 3 17:00 | VER-38 | feat/ver-38-user-model | User model updates |

Which checkpoint to resume? (1 = most recent, recommended)
```

### Step 3: Load and Present

Read the checkpoint file. Present a concise summary:

```
## Resuming: VER-42 — Refactor auth middleware

**Branch:** feat/ver-42-auth-refactor
**Last active:** Apr 7, 15:30
**Ticket status:** In Progress

### Completed
- Extracted auth middleware from monolithic handler
- Created new auth/middleware.py with JWT validation
- Updated route handlers, added unit tests

### Remaining
- [ ] Integration tests for auth flow
- [ ] Update API docs
- [ ] Specialist review → PR

### Open Questions
- Should we support refresh tokens in this ticket or defer?
```

### Step 4: Restore Context

1. Check if the branch still exists: `git branch --list "feat/ver-42-*"`
2. If on a different branch, offer to switch: `git checkout feat/ver-42-auth-refactor`
3. Check if the ticket status is still "In Progress" via Linear MCP
4. If status changed (e.g., someone else moved it), warn the user

### Step 5: Continue

```
Ready to continue. Pick up where you left off — the next step is integration tests.
Want to continue with /implement VER-42?
```

---

## List Mode

Show all checkpoints with status:

```bash
find "$_PROJ/checkpoints" -name "*.md" -type f | xargs ls -1t 2>/dev/null
```

Present as a table, and offer to resume or delete old ones.

## Wrap Up

```bash
~/.claude/skills/linear-sdlc/bin/lsdlc-timeline-log '{"skill":"checkpoint","event":"completed","branch":"'"$_BRANCH"'","outcome":"DONE","mode":"save|resume","session":"'"$_SESSION_ID"'"}' 2>/dev/null
```
