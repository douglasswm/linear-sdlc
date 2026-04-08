---
name: implement
description: |
  Full implementation lifecycle for a Linear ticket. Loads ticket context,
  creates branch, implements code, runs specialist self-review, creates PR.
  Use when: "implement VER-42", "work on ticket", "start VER-", "build this ticket".
model: sonnet
effort: medium
allowed-tools:
  - Bash
  - Read
  - Write
  - Edit
  - Glob
  - Grep
  - Agent
  - AskUserQuestion
---

# /implement — Full Implementation Lifecycle

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
  [ "$_LEARN_COUNT" -gt 0 ] && ~/.claude/skills/linear-sdlc/bin/lsdlc-learnings-search --limit 5 2>/dev/null || true
else
  echo "LEARNINGS: 0"
fi

_WIKI_PAGES=$(find "$_PROJ/wiki" -name "*.md" ! -name "index.md" ! -name "log.md" 2>/dev/null | wc -l | tr -d ' ')
echo "WIKI: $_WIKI_PAGES pages"

if [ -f "$_PROJ/timeline.jsonl" ]; then
  _LAST=$(grep "\"branch\":\"${_BRANCH}\"" "$_PROJ/timeline.jsonl" 2>/dev/null | grep '"event":"completed"' | tail -1)
  [ -n "$_LAST" ] && echo "LAST_SESSION: $_LAST"
fi

_SESSION_ID="$$-$(date +%s)"
~/.claude/skills/linear-sdlc/bin/lsdlc-timeline-log '{"skill":"implement","event":"started","branch":"'"$_BRANCH"'","session":"'"$_SESSION_ID"'"}' 2>/dev/null &

echo "---"
```

## Step 1: Parse Arguments

The user invokes this as `/implement VER-42` or `/implement <ticket-id>`.

Extract the ticket identifier from the arguments. If no ticket ID is provided, use AskUserQuestion to ask which ticket to implement.

## Step 2: Load Ticket Context

Use the Linear MCP server to fetch the ticket:
- Title, description, status, priority, labels, assignee
- If the ticket has a **parent issue**, fetch it too (for feature-level context)
- If the description references a **spec file** (e.g., `specs/auth-refactor.md`), read it
- Check for **sub-issues** — if this is a parent, list children and ask which to start with

Display a concise ticket summary:
```
TICKET: VER-42 — Refactor auth middleware
STATUS: Todo | PRIORITY: High | LABELS: backend, security
PARENT: VER-40 — Auth system overhaul
DESCRIPTION: <first 3 lines>
```

## Step 3: Pre-flight Checks

Before starting work, verify:

1. **Status check** — Is the ticket already "In Progress" assigned to someone else? If so, warn and ask to proceed.
2. **Branch check** — Does a branch for this ticket already exist?
   - If yes and we're on it: "Continuing existing work on branch `feat/ver-42-auth-refactor`"
   - If yes and we're NOT on it: offer to switch or create a new branch
   - If no: proceed to create branch
3. **Blocker check** — Does the ticket have dependencies that aren't Done?
   - If blocked: display blockers, offer to work on a blocker instead or override
4. **Working tree check** — Is the working tree clean? If dirty, ask to stash or commit first.

If any check fails critically, report BLOCKED status and exit.

## Step 4: Start Work

1. **Set status** — Use Linear MCP to set the ticket to "In Progress"
2. **Create branch** — Derive branch name from ticket:
   ```bash
   # Pattern: feat/{ticket-id-lowercase}-{short-description}
   # Example: feat/ver-42-auth-refactor
   git checkout -b "feat/$(echo 'VER-42' | tr '[:upper:]' '[:lower:]')-$(echo 'auth refactor' | tr ' ' '-' | tr -cd 'a-z0-9-')"
   ```
3. **Announce** — "Started VER-42 on branch `feat/ver-42-auth-refactor`. Let's implement."

## Step 5: Plan (If Complex)

Determine if the ticket needs a plan:
- More than 3 acceptance criteria in the description
- Has "complex" or "large" label
- The description is longer than 500 words
- User explicitly asks for a plan

If planning is needed:
1. Analyze the ticket requirements and codebase
2. Write a step-by-step implementation plan
3. Present the plan to the user for confirmation
4. Proceed only after approval

If the ticket is straightforward, skip planning and proceed directly.

## Step 6: Implement

This is where the actual coding happens. The human and Claude collaborate to implement the ticket.

**During implementation, follow these practices:**

- Refer back to the ticket's acceptance criteria regularly
- After completing a logical chunk of work, suggest committing:
  ```
  "Good checkpoint — want to commit these changes before continuing?"
  ```
- If you discover something non-obvious about the project, log a learning:
  ```bash
  ~/.claude/skills/linear-sdlc/bin/lsdlc-learnings-log '{"skill":"implement","type":"TYPE","key":"KEY","insight":"INSIGHT","confidence":N,"source":"observed"}'
  ```
- If you encounter a blocker or the requirements are unclear, use AskUserQuestion

**When the user signals implementation is complete** (or all acceptance criteria are met), proceed to Step 7.

## Step 7: Specialist Self-Review

Before creating a PR, run specialist reviews on the diff.

### 7a: Generate the diff

```bash
# Find the base branch (development, dev, or main)
BASE_BRANCH=$(git rev-parse --verify development 2>/dev/null && echo development || git rev-parse --verify dev 2>/dev/null && echo dev || echo main)
git diff "$BASE_BRANCH"...HEAD
```

### 7b: Dispatch specialists

Launch **parallel sub-agents** (using the Agent tool) for each applicable specialist:

| Specialist | When to dispatch | Checklist |
|-----------|-----------------|-----------|
| **Testing** | Always | Read `implement/specialists/testing.md` |
| **Security** | When diff touches auth, API, input handling, or env files | Read `implement/specialists/security.md` |
| **Performance** | When diff touches DB queries, API endpoints, loops, or data processing | Read `implement/specialists/performance.md` |
| **Code Quality** | Always | Read `implement/specialists/code-quality.md` |

Each sub-agent receives:
- The full `git diff` output
- The specialist checklist from the corresponding file
- Instructions to return findings as structured JSON

### 7c: Collect and present findings

Merge all specialist findings. Deduplicate by file + line number.

Classify each finding:
- **Critical** — Must fix before PR. Blocks merge.
- **Warning** — Should discuss with user. May or may not need fixing.
- **Nit** — Minor suggestion. Skip unless user wants to address.

Present findings grouped by severity:

```
## Specialist Review Results

### Critical (must fix)
- [testing] auth_handler.py:42 — No test for expired token path
- [security] auth_handler.py:67 — User input passed directly to SQL query

### Warnings (discuss)
- [performance] user_service.py:120 — N+1 query in user list endpoint

### Nits (0 found)
```

If there are **Critical** findings:
1. Fix each one
2. Re-run the affected specialist to verify the fix
3. Only proceed to PR when zero Critical findings remain

If there are **Warnings**, present them to the user with AskUserQuestion and let them decide.

### 7d: Log review findings

```bash
# Save findings to branch-specific review file
echo '<FINDINGS_JSON>' >> "$_PROJ/$(echo $_BRANCH | tr '/' '-')-reviews.jsonl"
```

### 7e: Completeness check

Before creating the PR, scan the diff for placeholders and verify acceptance-criteria coverage. This is **advisory, not blocking** — the user decides how to proceed when something is flagged.

```bash
# Placeholder / TODO scan (warn only)
git diff "$BASE_BRANCH"...HEAD | grep -nE '(TODO|FIXME|XXX|<placeholder>|<PLACEHOLDER>)' \
  || echo "  (no placeholders)"
```

Then walk through this checklist aloud, one line at a time:

- [ ] All acceptance criteria from the ticket have corresponding code changes (list each criterion → point at the file/line that satisfies it)
- [ ] No new `TODO`/`FIXME`/`XXX` in this diff — or, if any, each has a follow-up ticket
- [ ] Every new function/class has at least one call site (unless it's a public API entry point)
- [ ] Every new file is imported, routed, or otherwise referenced from existing code

If any item fails, report the gap and use `AskUserQuestion`:

```
**Re-ground:** Completeness check surfaced a gap before PR creation.
**Context:** {which item failed and why it matters}

**Options:**
1. **Fix now** — address the gap before PR
2. **Create a follow-up ticket** — file it in Linear, PR as-is
3. **Accept as-is** — proceed to PR (user takes responsibility)
```

Respect the user's choice — this is a nudge, not a gate.

## Step 8: Create PR

1. **Push branch:**
   ```bash
   git push -u origin HEAD
   ```

2. **Create PR** via `gh`:
   ```bash
   gh pr create --title "VER-42: <ticket title>" --body "$(cat <<'EOF'
   ## Summary
   <ticket description summary>

   ## Changes
   <bullet list of key changes>

   ## Linear Ticket
   [VER-42](https://linear.app/team/issue/VER-42)

   ## Specialist Review
   - Testing: <pass/N findings>
   - Security: <pass/N findings/skipped>
   - Performance: <pass/N findings/skipped>
   - Code Quality: <pass/N findings>

   ## Test Plan
   - [ ] <from acceptance criteria>
   EOF
   )"
   ```

3. **Update Linear** — Use MCP to set ticket status to "In Review"

## Step 9: Wrap Up

**Follow `references/verification-gate.md`** — evidence before claims. Run the verification commands first, paste the literal output, then state `STATUS: DONE`.

1. **Capture fresh evidence.** Run and display the literal output:
   ```bash
   git log -1 --oneline
   git status --short
   gh pr view --json url,state -q '.url + " (" + .state + ")"' 2>/dev/null || echo "PR not created"
   ```

2. **Log completion:**
   ```bash
   ~/.claude/skills/linear-sdlc/bin/lsdlc-timeline-log '{"skill":"implement","event":"completed","branch":"'"$_BRANCH"'","outcome":"DONE","ticket":"VER-42","pr":"PR_URL","session":"'"$_SESSION_ID"'"}' 2>/dev/null
   ```

3. **Log any learnings** discovered during implementation

4. **Report status** — cite the verification output verbatim, don't restate from memory:
   ```
   STATUS: DONE
   EVIDENCE:
     <literal `git log -1 --oneline` output>
     <literal `git status --short` output>
     <literal `gh pr view` output or "PR not created">
   SUMMARY: Implemented VER-42 (auth middleware refactor), PR #123 created, ticket set to In Review
   ```

## Important Rules

1. **Never skip specialist review.** Even for "small" changes. The review catches what humans miss.
2. **Never force-push** without asking the user first.
3. **Always link the Linear ticket** in the PR description.
4. **Update Linear status** at each transition: Todo → In Progress → In Review.
5. **Log learnings** when you discover something non-obvious about the project.
6. **Ask before acting** on anything destructive (reset, rebase, delete).
