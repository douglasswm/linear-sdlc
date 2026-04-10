# Linear issue description templates

Used by `/create-tickets` (`skills/create-tickets/SKILL.md`) when writing the
`description` field on Linear issues. Two **base** shapes: one for parent/epic
issues, one for sub-issues. Both can be extended by **type-specific overlays**
in `templates/issue-types/` — see "Overlays" below.

**Why these shapes matter.** The `Acceptance criteria` checklist on sub-issues
is read back by `/implement` when planning and verifying work — it is the
contract, not decoration. `/implement` gates its planning depth on the number
of acceptance criteria (`skills/implement/SKILL.md` Step 1b) and copies them
into the PR description (Step 7). A sub-issue without a concrete
`Acceptance criteria` checklist is broken.

Claude fills in the `<...>` placeholders from the spec file. Omit a section
only if the spec genuinely has nothing to say there — do not emit empty
headings. If a section has nothing to say, write `none` rather than dropping
the heading.

## Overlays

When a planned ticket carries a type label (`epic`, `story`, `bug`, `spike`,
`chore`), `/create-tickets` and `/update-tickets` load the matching overlay
from `templates/issue-types/<type>.md` on top of the relevant base shape:

- `epic` → applied on top of the **parent** shape (adds Outcome, KPIs, Personas served, Milestones, Risks)
- `story` → applied on top of the **sub-issue** shape (replaces freeform AC with Gherkin, adds Designs/Telemetry/Copy)
- `bug` → applied on top of the **sub-issue** shape (replaces Requirements with Steps to reproduce / Expected / Actual / Environment / Severity / Suspected root cause)
- `spike` → applied on top of the **sub-issue** shape (replaces Requirements + AC with Question / Time-box / Deliverable / Decision criteria)

If a ticket has no type label, the base shape below is used unchanged.
Overlays follow the same fill rules: write `none` rather than dropping a
heading.

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

## Test plan
<How this gets verified. Unit tests added, integration tests added, manual QA steps. Write `none` for trivial changes that genuinely need no test coverage.>

## Dependencies
- Blocked by: <ticket id, or "none">

## Spec
`specs/<file>.md`

## Definition of done

Shared baseline that applies to every sub-issue. `/implement` walks this
list during the Step 7 completeness check.

- [ ] All `Acceptance criteria` items above pass
- [ ] Tests added or updated per the `Test plan`, all green locally
- [ ] No new `TODO` / `FIXME` / `XXX` in the diff (or each has a follow-up ticket)
- [ ] Docs updated if user-visible behavior changed (README, CLAUDE.md, in-code comments at non-obvious decision points)
- [ ] Telemetry / logging added if user-visible (or noted as N/A)
- [ ] PR opened, ticket linked, status moved to In Review
```
