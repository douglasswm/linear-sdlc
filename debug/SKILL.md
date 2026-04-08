---
name: debug
description: |
  Systematic bug investigation. Reproduce, instrument at component boundaries,
  observe, then propose root cause. Phase-1 focus — evidence before hypothesis.
  Use when: "debug", "why is this broken", "investigate bug", "test is failing".
model: sonnet
effort: medium
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
~/.claude/skills/linear-sdlc/bin/lsdlc-timeline-log '{"skill":"debug","event":"started","branch":"'"$_BRANCH"'","session":"'"$_SESSION_ID"'"}' 2>/dev/null &

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

## Soft Invariant

**Recommendation, not mandate:** don't propose fixes during Steps 1-4. If you feel the urge to jump ahead — because it "looks obvious" — note it as a candidate, log a learning about the temptation if it felt strong, and finish gathering evidence first. The user can override at any point.

```bash
~/.claude/skills/linear-sdlc/bin/lsdlc-learnings-log '{"skill":"debug","type":"operational","key":"premature-fix-urge","insight":"Felt tempted to jump to fix at boundary X before completing observation; evidence later showed the bug was at boundary Y","confidence":3,"source":"observed"}'
```

## Step 7: Log Learnings

If the investigation revealed something non-obvious about the project — a hidden coupling, a misleading error message, a wrong assumption baked into a comment — log it:

```bash
~/.claude/skills/linear-sdlc/bin/lsdlc-learnings-log '{"skill":"debug","type":"TYPE","key":"KEY","insight":"INSIGHT","confidence":N,"source":"observed"}'
```

Types: `operational`, `pitfall`, `convention`, `dependency`, `architecture`.

## Wrap Up

```bash
~/.claude/skills/linear-sdlc/bin/lsdlc-timeline-log '{"skill":"debug","event":"completed","branch":"'"$_BRANCH"'","outcome":"DONE","session":"'"$_SESSION_ID"'"}' 2>/dev/null
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
