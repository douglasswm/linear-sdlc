# User story overlay

Applied **on top of** the sub-issue shape in `templates/issue-template.md`
when a sub-issue is labeled `story`. The base sub-issue shape (Context,
Requirements, Acceptance criteria, Implementation notes, Dependencies,
Spec, Test plan) stays — but this overlay **replaces** the freeform
`Acceptance criteria` checklist with Gherkin-style scenarios, which read
back cleanly to `/implement` because each scenario is still a `- [ ]`
line.

The overlay also adds three subsections that user-facing work needs:
Designs, Telemetry, Copy. Each accepts `none` if not applicable —
e.g. backend stories with no UI keep `Designs: none`.

`/create-tickets` reads the base sub-issue template, then **substitutes**
the User story header at the top and the Gherkin acceptance criteria,
and **appends** Designs / Telemetry / Copy after Implementation notes.

---

```markdown
## User story

As a [<persona>](../../docs/personas/<slug>.md), I want to <action> so that <benefit>.

## Context

<1–3 sentences: why this story exists and which slice of the parent epic it delivers. Assume the reader has not read the spec.>

## Requirements

- <concrete thing to build>
- <concrete thing to build>

## Acceptance criteria

Each scenario must be testable. `/implement` reads these as the binding contract.

- [ ] **Given** <starting state>, **When** <action>, **Then** <observable outcome>
- [ ] **Given** <starting state>, **When** <action>, **Then** <observable outcome>
- [ ] **Given** <starting state>, **When** <action>, **Then** <observable outcome>

## Designs

<Link to Figma / mockup / wireframe — or `none` if no UI.>

## Telemetry

<Events to fire and properties to capture — or `none`.>

- `<event_name>` — fired when <trigger>, props: `<key>`, `<key>`

## Copy

<User-facing strings, error messages, empty states — or `none`.>

## Implementation notes

<Files / modules / functions likely touched. Key decisions from the spec. Anything non-obvious a future implementer would want before opening a PR.>

## Dependencies

- Blocked by: <ticket id, or "none">

## Spec

`specs/<file>.md`
```
