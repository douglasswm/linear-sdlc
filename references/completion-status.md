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

```
STATUS: DONE_WITH_CONCERNS
SUMMARY: <what was accomplished>
CONCERNS:
- <concern 1>
- <concern 2>
```

## BLOCKED
Cannot proceed. Explain what's blocking and what the user can do.

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

## Logging

After reporting status, log the completion event:

```bash
~/.claude/skills/linear-sdlc/bin/lsdlc-timeline-log '{"skill":"SKILL_NAME","event":"completed","branch":"BRANCH","outcome":"STATUS","session":"SESSION_ID"}' 2>/dev/null
```
