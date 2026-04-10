# Bug overlay

Applied **on top of** the sub-issue shape in `templates/issue-template.md`
when a sub-issue is labeled `bug`. The base sub-issue shape (Context,
Requirements, Acceptance criteria, Implementation notes, Dependencies,
Spec, Test plan) stays — but this overlay **replaces** the Requirements
section with the bug-specific fields a reproducer needs: steps to
reproduce, expected vs actual, environment, severity, suspected root
cause.

Acceptance criteria is kept (the fix is verified against it) and is the
contract `/implement` reads. Severity drives Linear priority via
`/create-tickets`: sev1 → priority 1 (urgent), sev2 → priority 2 (high),
sev3 → priority 3 (medium).

---

```markdown
## Context

<1–3 sentences: when was this first noticed, which user / system surfaced it, blast radius. Assume the reader has not seen the original report.>

## Steps to reproduce

1. <first action>
2. <second action>
3. <third action>

## Expected behavior

<What should happen.>

## Actual behavior

<What actually happens. Include error message verbatim if there is one.>

## Environment

- **Version / commit:** <git sha or release tag>
- **OS / browser:** <e.g. macOS 14.4, Chrome 124>
- **Account / role:** <if relevant>
- **Other:** <feature flags, plan tier, region>

## Severity

**sev<1|2|3>** — <one-line justification, e.g. "blocks all checkouts" / "broken for one user, workaround exists">

## Suspected root cause

<Optional hypothesis. One sentence. Mark as `unknown` if you have no theory yet — that's also useful signal.>

## Acceptance criteria

- [ ] Reproduction case from "Steps to reproduce" no longer triggers the actual behavior
- [ ] Regression test added that would have caught this
- [ ] <any other testable criterion specific to this fix>

## Implementation notes

<Files / modules / functions likely touched. Anything non-obvious a future implementer would want before opening a PR.>

## Dependencies

- Blocked by: <ticket id, or "none">

## Spec

`specs/<file>.md` — or `none` if filed directly without a spec.
```
