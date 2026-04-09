# Linear issue description templates

Used by `/create-tickets` (`skills/create-tickets/SKILL.md`) when writing the
`description` field on Linear issues. Two shapes: one for parent/epic issues,
one for sub-issues.

**Why these shapes matter.** The `Acceptance criteria` checklist on sub-issues
is read back by `/implement` when planning and verifying work — it is the
contract, not decoration. `/implement` gates its planning depth on the number
of acceptance criteria (`skills/implement/SKILL.md` Step 1b) and copies them
into the PR description (Step 7). A sub-issue without a concrete
`Acceptance criteria` checklist is broken.

Claude fills in the `<...>` placeholders from the spec file. Omit a section
only if the spec genuinely has nothing to say there — do not emit empty
headings.

---

## Parent issue template

```markdown
## Problem
<1–3 sentences from the spec's Problem section — what's broken or missing, who is affected>

## Goal
<1–2 sentences describing the desired end state once all sub-issues ship>

## Scope
- <sub-issue 1 title>
- <sub-issue 2 title>
- <sub-issue 3 title>

## Out of scope
- <item explicitly deferred, from the spec's Out of Scope section>

## Spec
`specs/<file>.md`
```

---

## Sub-issue template

```markdown
## Context
<1–3 sentences: why this ticket exists and which slice of the parent it delivers. Assume the reader has not read the spec.>

## Requirements
- <concrete thing to build>
- <concrete thing to build>

## Acceptance criteria
- [ ] <testable criterion 1>
- [ ] <testable criterion 2>
- [ ] <testable criterion 3>

## Implementation notes
<Files / modules / functions likely touched. Key decisions carried over from the spec's Technical Approach. Anything non-obvious a future implementer would want to know before opening a PR.>

## Dependencies
- Blocked by: <ticket id, or "none">

## Spec
`specs/<file>.md`
```
