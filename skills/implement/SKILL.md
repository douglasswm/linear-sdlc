---
name: implement
description: |
  Full implementation lifecycle for a Linear ticket. Loads ticket context,
  creates branch, implements code, runs specialist self-review, creates PR.
  Use when: "implement VER-42", "work on ticket", "start VER-", "build this ticket".
model: sonnet
effort: medium
argument-hint: "[ticket-id]"
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
SKILL_NAME=implement . "$LINEAR_SDLC_ROOT/references/preamble.sh"

# Learnings + last session (skill-specific display)
# (Wiki info is rendered by the shared preamble.)
_LEARN_FILE="$_PROJ/learnings.jsonl"
if [ -f "$_LEARN_FILE" ]; then
  _LEARN_COUNT=$(wc -l < "$_LEARN_FILE" | tr -d ' ')
  echo "LEARNINGS: $_LEARN_COUNT entries"
  [ "$_LEARN_COUNT" -gt 0 ] && lsdlc-learnings-search --limit 5 2>/dev/null || true
else
  echo "LEARNINGS: 0"
fi

if [ -f "$_PROJ/timeline.jsonl" ]; then
  _LAST=$(grep "\"branch\":\"${_BRANCH}\"" "$_PROJ/timeline.jsonl" 2>/dev/null | grep '"event":"completed"' | tail -1)
  [ -n "$_LAST" ] && echo "LAST_SESSION: $_LAST"
fi

echo "---"
```

## Step 1: Parse Arguments

The user invokes this as `/implement VER-42` or `/implement <ticket-id>`.

Extract the ticket identifier from the arguments. If no ticket ID is provided, use AskUserQuestion to ask which ticket to implement.

## Step 2: Load Ticket Context

Fetch the ticket via the bundled `lsdlc-linear` helper. A single call returns the title, description, status, priority, labels, assignee, parent, sub-issues (children), relations, and recent comments — no follow-up calls needed:

```bash
TICKET_ID="VER-42"  # substitute the actual identifier
TICKET_JSON=$(lsdlc-linear get-issue "$TICKET_ID")
```

Parse and display a concise summary:

```bash
printf '%s' "$TICKET_JSON" | node -e '
  const t = JSON.parse(require("fs").readFileSync(0, "utf8"));
  const labels = (t.labels?.nodes || []).map(l => l.name).join(", ") || "(none)";
  const parent = t.parent ? `${t.parent.identifier} — ${t.parent.title}` : "(none)";
  console.log(`TICKET: ${t.identifier} — ${t.title}`);
  console.log(`STATUS: ${t.state.name} | PRIORITY: ${t.priorityLabel || "None"} | LABELS: ${labels}`);
  console.log(`PARENT: ${parent}`);
  console.log("DESCRIPTION:");
  console.log((t.description || "").split("\n").slice(0, 3).join("\n"));
'
```

If the description references a **spec file** (e.g., `specs/auth-refactor.md`), read it. If `children.nodes` is non-empty, this is a parent — list the children and ask which to start with.

## Step 3: Pre-flight Checks

Before starting work, verify:

1. **Status check** — Is the ticket already "In Progress" assigned to someone else? Read `state.name` and `assignee` from `$TICKET_JSON`. If it's In Progress and assigned to a different user, warn and ask to proceed.
2. **Branch check** — Does a branch for this ticket already exist?
   - If yes and we're on it: "Continuing existing work on branch `feat/ver-42-auth-refactor`"
   - If yes and we're NOT on it: offer to switch or create a new branch
   - If no: proceed to create branch
3. **Blocker check** — Does the ticket have dependencies that aren't Done? Parse `relations.nodes[]` from `$TICKET_JSON` — for each relation where `type` is `blocks`, the `relatedIssue.state.name` should be `Done` or `Cancelled`. Display any unresolved blockers and offer to work on a blocker instead or override.
4. **Working tree check** — Is the working tree clean? If dirty, ask to stash or commit first.

If any check fails critically, capture the failure as a learning before
reporting BLOCKED:

```bash
# Pick the right key for the specific failure
case "$FAILURE" in
  ticket-not-found)
    _lsdlc_capture_error step-3 "ticket-fetch-failed" "lsdlc-linear get-issue $TICKET_ID failed — ticket missing or API key invalid. Verify identifier and re-run."
    ;;
  unresolved-blockers)
    _lsdlc_capture_error step-3 "blocker-cycle" "Ticket $TICKET_ID has unresolved blockers. Work on the blocker first or break the cycle in Linear."
    ;;
  dirty-tree)
    _lsdlc_capture_error step-3 "dirty-working-tree" "Working tree dirty when starting $TICKET_ID. Stash or commit before /implement."
    ;;
esac
```

Then report the BLOCKED status (per `references/completion-status.md`)
and exit.

## Step 4: Start Work

1. **Set status** — `lsdlc-linear set-status "$TICKET_ID" "In Progress"`
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
  lsdlc-learnings-log '{"skill":"implement","type":"TYPE","key":"KEY","insight":"INSIGHT","confidence":N,"source":"observed"}'
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
| **Testing** | Always | `$LINEAR_SDLC_ROOT/skills/implement/specialists/testing.md` |
| **Security** | When diff touches auth, API, input handling, or env files | `$LINEAR_SDLC_ROOT/skills/implement/specialists/security.md` |
| **Performance** | When diff touches DB queries, API endpoints, loops, or data processing | `$LINEAR_SDLC_ROOT/skills/implement/specialists/performance.md` |
| **Code Quality** | Always | `$LINEAR_SDLC_ROOT/skills/implement/specialists/code-quality.md` |

`$LINEAR_SDLC_ROOT` is exported by the preamble. Read the file in the parent skill turn (you have file-system access), then pass its contents inline in the sub-agent's prompt — sub-agents have their own working directory and won't be able to resolve a relative path.

Each sub-agent receives:
- The full `git diff` output
- The specialist checklist content (read by the parent skill from `$LINEAR_SDLC_ROOT/skills/implement/specialists/<name>.md` and embedded in the prompt)
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
# Re-derive BASE_BRANCH — shell state doesn't persist across bash tool calls,
# so Step 7a's assignment isn't in scope here.
BASE_BRANCH=$(git rev-parse --verify development 2>/dev/null && echo development || git rev-parse --verify dev 2>/dev/null && echo dev || echo main)

# Placeholder / TODO scan — only match ADDED lines (prefix +), not removed ones.
git diff "$BASE_BRANCH"...HEAD | grep -E '^\+.*(TODO|FIXME|XXX|<placeholder>|<PLACEHOLDER>)' \
  || echo "  (no placeholders)"
```

Then walk through this checklist aloud, one line at a time:

- [ ] All acceptance criteria from the ticket have corresponding code changes (list each criterion → point at the file/line that satisfies it)
- [ ] No new `TODO`/`FIXME`/`XXX` in this diff — or, if any, each has a follow-up ticket
- [ ] Every new function/class has at least one call site (unless it's a public API entry point)
- [ ] Every new file is imported, routed, or otherwise referenced from existing code

If any item fails, capture the gap as a learning, then report the gap
and use `AskUserQuestion`:

```bash
_lsdlc_capture_error step-7e "completeness-gap" "Completeness check failed for $TICKET_ID at item: <which item>. Followed up with <choice>."
```

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

3. **Update Linear** — `lsdlc-linear set-status "$TICKET_ID" "In Review"`

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
   lsdlc-timeline-log '{"skill":"implement","event":"completed","branch":"'"$_BRANCH"'","outcome":"DONE","ticket":"VER-42","pr":"PR_URL","session":"'"$_SESSION_ID"'"}' 2>/dev/null
   ```

3. **Log any learnings** discovered during implementation

4. **Auto-ingest the ticket into the wiki** (if `wiki_auto_ingest` is enabled, default true).

   Check first:
   ```bash
   WIKI_DIR="$(lsdlc-wiki path 2>/dev/null)"
   AUTO_INGEST="$(lsdlc-config get wiki_auto_ingest 2>/dev/null || echo true)"
   ```

   If `$WIKI_DIR` is non-empty AND the directory exists AND `$AUTO_INGEST` is `true`:

   Run the **fan-out ingest** workflow from the `/wiki` skill and the wiki's
   own `CLAUDE.md` schema. In summary:

   a. Read `$WIKI_DIR/index.md` to find entity/concept pages related to the
      files in `git diff "$BASE_BRANCH"...HEAD`.
   b. Read the related existing pages.
   c. Draft `tickets/<TICKET-ID>.md` with: summary, affected files (diff
      paths), design notes, links to touched entity/concept pages using
      relative markdown links.
   d. Draft updates to each related entity/concept page. This is the
      fan-out — expect to touch 3–10 pages. Cross-link them back to the
      ticket page.
   e. If new claims contradict existing text on any page, insert the
      contradiction callout from the wiki `CLAUDE.md` — never silently
      overwrite.
   f. **Secret-scan every draft** before writing. Pass all drafts to a
      single `lsdlc-wiki secret-scan` invocation — it exits 3 on any hit.
      Gate steps (g) through (l) on the exit code. Any hit aborts the
      **entire** ingest — no partial writes.
      ```bash
      if lsdlc-wiki secret-scan "$WIKI_DIR/tickets/$TICKET_ID.md" "$WIKI_DIR/entities/auth.md" "<other drafts>"; then
        WIKI_SCAN_OK=1
      else
        WIKI_SCAN_OK=0
        echo "WIKI: ingest aborted — secret-scan found issues, no files written"
      fi
      ```
      Only if `$WIKI_SCAN_OK -eq 1`, proceed with steps g–l. Otherwise
      skip the rest of step 4 entirely and continue to step 5.
   g. Write all drafts.
   h. For each new/changed page, run
      `lsdlc-wiki index-upsert <rel-path> <Category> <one-line-summary>`.
   i. Append one consolidated log entry:
      ```bash
      lsdlc-wiki log-append ingest "$TICKET_ID: <ticket title>" --touched "<comma-separated rel paths>"
      ```
   j. Print a summary line:
      `WIKI: wrote tickets/$TICKET_ID.md + updated <N> entity/concept pages (secret-scan: ok)`
   k. If `wiki_qmd_auto_index=true` and `qmd` is installed, reindex in the
      background: `lsdlc-wiki qmd-refresh &`
   l. If `wiki_linear_auto_sync=true`, follow up with
      `lsdlc-wiki sync-linear` to mirror the new pages to Linear.

   **Never auto-commit.** Leave every wiki edit in the working tree for
   the user to review with `git diff .linear-sdlc/wiki/` and include in
   their next commit when ready.

   If `$AUTO_INGEST` is `false`, print a candidate list instead:
   `WIKI: candidates for /wiki ingest $TICKET_ID — tickets/$TICKET_ID.md, <list related pages>`

5. **Report status** — cite the verification output verbatim, don't restate from memory:
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
