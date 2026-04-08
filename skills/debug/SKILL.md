---
name: debug
description: |
  Systematic bug investigation. Reproduce, instrument at component boundaries,
  observe, then propose root cause. Phase-1 focus — evidence before hypothesis.
  Use when: "debug", "why is this broken", "investigate bug", "test is failing".
model: sonnet
effort: medium
argument-hint: "[bug summary]"
allowed-tools:
  - Bash
  - Read
  - Write
  - Edit
  - Glob
  - Grep
  - AskUserQuestion
---

# /debug — Systematic Bug Investigation

The goal of this skill is **diagnostic rigor at component boundaries** — gather evidence before proposing fixes. This is a soft discipline, not an iron law: if the evidence is already clear, don't manufacture ceremony. User Sovereignty still applies — the user decides when to jump ahead.

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
SKILL_NAME=debug . "$LINEAR_SDLC_ROOT/references/preamble.sh"

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

## Step 1: Reproduce

Get a reliable, minimal reproduction. No analysis yet — just capture:

1. The exact command, request, or user action that triggers the bug.
2. The verbatim failing output (stack trace, error message, wrong value). Paste it into the response exactly as seen.
3. The environment: branch, commit, relevant env vars, any non-default config.

If you can't reproduce, stop and ask the user for a clearer repro before continuing.

## Step 2: Identify Component Boundaries

List the components on the data path between input and failure point. Example:

```
request → router → auth middleware → handler → validator → db query → response serializer → client
```

Keep it concrete to this codebase, not generic. The point is to name the boundaries at which data crosses from one responsibility to another — those are the places where wrong data can first appear.

## Step 3: Instrument

Add temporary logging, assertions, or prints **at each boundary** to observe the data as it flows. Before running:

- Show the user the diff of the instrumentation changes
- Keep each log line prefixed with something greppable (e.g. `DBG:`) so cleanup is trivial later
- Do not alter behavior — only observe

## Step 4: Observe

Re-run the repro with instrumentation in place. Capture the layered output. Walk through it from input to failure point and identify **the first boundary where data becomes wrong**. That boundary, not the crash site, is where the bug lives.

If the output is ambiguous (wrong data at multiple places), add more instrumentation narrower to that region and re-run.

## Step 5: Hypothesize Root Cause

Now — and only now — explain what the evidence shows. Reference the specific boundary where the data first went wrong. State the hypothesis in one paragraph. If multiple hypotheses fit the evidence, list them and say which is most likely and why.

## Step 6: Propose Minimal Fix

One change, one reason. The fix should address the root cause identified in Step 5, not just mask the symptom. Present it via `AskUserQuestion`:

```
**Re-ground:** Root cause identified: {one-line summary}.
**Context:** The wrong data first appears at {boundary}, because {reason}.

**Options:**
1. **Apply the minimal fix** — {one-sentence description of the change}
2. **Investigate further** — keep gathering evidence before fixing
3. **Hand back** — you drive the fix, I'll stand down
```

If the user picks option 1, apply the fix. Remove the instrumentation added in Step 3. Re-run the repro to confirm the bug is gone.

## Step 6.5: Auto-Write Incident to Wiki (on confirmed fix only)

If the user picked **Apply the minimal fix** AND the re-run confirms the
bug is resolved, auto-write an incident page (gated by `wiki_auto_incident`,
default true). **Do NOT write on the "Investigate further" or "Hand back"
branches** — a half-debugged session is not a well-formed incident.

```bash
WIKI_DIR="$(lsdlc-wiki path 2>/dev/null)"
AUTO_INCIDENT="$(lsdlc-config get wiki_auto_incident 2>/dev/null || echo true)"
```

If `$WIKI_DIR` is non-empty AND the directory exists AND `$AUTO_INCIDENT`
is `true`:

1. Read `$WIKI_DIR/index.md` to find related entity/concept pages on the
   data path identified in Step 2.
2. Read those related pages.
3. Derive a kebab-case slug from the bug symptom (e.g.,
   `login-loop-on-expired-token`).
4. Draft `$WIKI_DIR/incidents/<slug>.md` with:
   - Frontmatter: `updated: <ISO timestamp>`, `sources:` list
   - Title
   - **Repro** — the exact command and verbatim failing output
   - **Boundary walk** — the components on the data path
   - **Root cause** — the specific boundary where data first went wrong,
     with a one-paragraph explanation
   - **Fix** — one-line description + a relative link to the fix commit
     if available (`git rev-parse HEAD` is fine)
   - **Related** — relative-link citations to the entity/concept pages
     you identified in step 1
5. Optionally draft small updates to the related entity pages adding a
   "Known issues" section or extending an existing one, with a relative
   link back to the incident. Insert contradiction callouts on any
   conflicting claims.
6. **Secret-scan every draft.** Pass all drafts to a single
   `lsdlc-wiki secret-scan` invocation — it exits 3 on any hit. Gate
   steps 7-11 on the exit code. Any hit aborts the **entire** ingest,
   no partial writes:
   ```bash
   if lsdlc-wiki secret-scan "$WIKI_DIR/incidents/<slug>.md" "<other drafts>"; then
     INCIDENT_SCAN_OK=1
   else
     INCIDENT_SCAN_OK=0
     echo "WIKI: incident write aborted — secret-scan found issues, no files written"
   fi
   ```
   Only if `$INCIDENT_SCAN_OK -eq 1`, continue with steps 7-11.
   Otherwise skip the rest of step 6.5 and return to the normal flow.
7. Write all drafts.
8. `lsdlc-wiki index-upsert incidents/<slug>.md Incidents "<short description>"`
9. For each updated entity page, run index-upsert too.
10. `lsdlc-wiki log-append ingest "incident: <slug>" --touched "<comma-separated paths>"`
11. Print a summary:
    `WIKI: wrote incidents/<slug>.md + updated <N> related pages (secret-scan: ok)`

If `$AUTO_INCIDENT` is `false`, print a single candidate line instead:
`WIKI: candidate for /wiki ingest --incident <slug>`

**Never auto-commit.** The user reviews the wiki diff before committing.

## Soft Invariant

**Recommendation, not mandate:** don't propose fixes during Steps 1-4. If you feel the urge to jump ahead — because it "looks obvious" — note it as a candidate, log a learning about the temptation if it felt strong, and finish gathering evidence first. The user can override at any point.

```bash
lsdlc-learnings-log '{"skill":"debug","type":"operational","key":"premature-fix-urge","insight":"Felt tempted to jump to fix at boundary X before completing observation; evidence later showed the bug was at boundary Y","confidence":3,"source":"observed"}'
```

## Step 7: Log Learnings

If the investigation revealed something non-obvious about the project — a hidden coupling, a misleading error message, a wrong assumption baked into a comment — log it:

```bash
lsdlc-learnings-log '{"skill":"debug","type":"TYPE","key":"KEY","insight":"INSIGHT","confidence":N,"source":"observed"}'
```

Types: `operational`, `pitfall`, `convention`, `dependency`, `architecture`.

## Wrap Up

```bash
lsdlc-timeline-log '{"skill":"debug","event":"completed","branch":"'"$_BRANCH"'","outcome":"DONE","session":"'"$_SESSION_ID"'"}' 2>/dev/null
```

```
STATUS: DONE
SUMMARY: Debugged {bug}; root cause {one-line}; fix applied and verified.
```

## Important Rules

1. **Evidence before hypothesis.** Follow the steps in order unless the user tells you otherwise.
2. **Name the boundary, not the symptom.** "Wrong value at X" is a root cause. "Response is wrong" is a symptom.
3. **Clean up instrumentation.** Before declaring done, remove `DBG:` logs and temporary asserts.
4. **Don't paper over flakiness.** If the repro is intermittent, say so — don't pretend a fix works because one run passed.
