# Completion Status Protocol

Every skill ends by reporting one of these statuses:

## DONE
All steps completed successfully. No concerns.

```
STATUS: DONE
SUMMARY: <one-line description of what was accomplished>
```

## DONE_WITH_CONCERNS
Completed, but with issues the user should be aware of.

**Required:** Before reporting this status, call `_lsdlc_capture_error`
(see "Error capture" below) for the underlying issue. Reporting concerns
without recording the learning means the next session rediscovers the
same problem.

```
STATUS: DONE_WITH_CONCERNS
SUMMARY: <what was accomplished>
CONCERNS:
- <concern 1>
- <concern 2>
```

## BLOCKED
Cannot proceed. Explain what's blocking and what the user can do.

**Required:** Before reporting this status, call `_lsdlc_capture_error`
with a stable key and a one-sentence insight. This is part of the
status protocol, not a nice-to-have. Skipping it means the next session
will rediscover the same failure.

```
STATUS: BLOCKED
BLOCKER: <what's preventing progress>
SUGGESTION: <what the user can do to unblock>
```

## NEEDS_CONTEXT
Missing information required to proceed.

```
STATUS: NEEDS_CONTEXT
MISSING: <what information is needed>
QUESTION: <specific question for the user>
```

## Error capture

`_lsdlc_capture_error` is a shell function defined in
`references/preamble.sh`. Every skill that sources the preamble has it
in scope.

```bash
_lsdlc_capture_error <step> <key> <insight>
```

- `<step>` — short label for where in the skill it failed (e.g. `step-4b`, `specialist-review`)
- `<key>` — stable slug for this failure mode (e.g. `linear-401-from-stale-key`). Same key on a re-run appends another row, but `lsdlc-learnings-search` dedups by key+type at read time, so noise is bounded.
- `<insight>` — one sentence: what failed and what fixed it / what to try next time. **No stack traces, no secrets, no argv dumps.**

Example, right before a BLOCKED report:

```bash
_lsdlc_capture_error step-1 "linear-api-unreachable" "lsdlc-linear get-issue returned non-zero — Linear API was unreachable, retried twice. Check network or LINEAR_API_KEY validity."
```

The function writes to `learnings.jsonl` (per-project local state dir,
with `type:"error"`) and to the timeline. It does **not** write to
`.linear-sdlc/wiki/log.md` — that file is committed and operational
failures don't belong in git history.

## Logging

After reporting status, log the completion event:

```bash
lsdlc-timeline-log '{"skill":"SKILL_NAME","event":"completed","branch":"BRANCH","outcome":"STATUS","session":"SESSION_ID"}' 2>/dev/null
```
