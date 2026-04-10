---
name: checkpoint
description: |
  Save and resume working state across sessions. Captures git state, conversation
  context, current Linear ticket, and remaining work.
  Use when: "checkpoint", "save progress", "where was I", "resume".
model: sonnet
effort: low
argument-hint: "[resume]"
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
SKILL_NAME=checkpoint . "$LINEAR_SDLC_ROOT/references/preamble.sh"

# List existing checkpoints (skill-specific display)
_CP_COUNT=$(find "$_PROJ/checkpoints" -name "*.md" -type f 2>/dev/null | wc -l | tr -d ' ')
echo "CHECKPOINTS: ${_CP_COUNT:-0} saved"
if [ "${_CP_COUNT:-0}" -gt 0 ]; then
  echo "LATEST:"
  find "$_PROJ/checkpoints" -name "*.md" -type f 2>/dev/null | xargs ls -1t 2>/dev/null | head -3
fi

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

**Follow `references/verification-gate.md`** — capture literal shell output before writing the checkpoint, not a paraphrase from conversation memory. A resumed checkpoint is only as trustworthy as its evidence.

Generate a timestamp and title, then capture git state verbatim:
```bash
TIMESTAMP=$(date +%Y%m%d-%H%M%S)
TITLE="ver-42-auth-refactor"

# Capture literal git output for the checkpoint file
GIT_STATUS=$(git status --short)
GIT_LAST_COMMIT=$(git log -1 --oneline)
GIT_DIFFSTAT=$(git diff --stat)
```

Write the checkpoint file, embedding the literal output under `## Git State (verbatim)`:

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

## Git State (verbatim)

Last commit:
```
abc1234 refactor: extract auth middleware
```

Working tree (`git status --short`):
```
 M auth/middleware.py
 M tests/test_auth.py
```

Diffstat (`git diff --stat`):
```
 auth/middleware.py  | 42 ++++++++++++++++--
 tests/test_auth.py  | 18 ++++++++
 2 files changed, 58 insertions(+), 2 deletions(-)
```

## Key Decisions Made
- Using PyJWT instead of python-jose (simpler API, fewer deps)
- Token expiry set to 1 hour (was 24 hours)
```

Save to: `$_PROJ/checkpoints/${TIMESTAMP}-${TITLE}.md`

If the write fails (filesystem error, permissions on `$_PROJ`), capture
and report BLOCKED:

```bash
_lsdlc_capture_error save-step-3 "checkpoint-write-failed" "Could not write checkpoint file to $_PROJ/checkpoints/. Check that ~/.linear-sdlc/projects/$_SLUG/ exists and is writable."
```

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
3. Check if the ticket status is still "In Progress" via direct API:
   ```bash
   lsdlc-linear get-issue VER-42 | node -e '
     const t = JSON.parse(require("fs").readFileSync(0, "utf8"));
     console.log(t.state.name);
   '
   ```
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
lsdlc-timeline-log '{"skill":"checkpoint","event":"completed","branch":"'"$_BRANCH"'","outcome":"DONE","mode":"save|resume","session":"'"$_SESSION_ID"'"}' 2>/dev/null
```
