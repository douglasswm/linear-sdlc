# Spike overlay

Applied **on top of** the sub-issue shape in `templates/issue-template.md`
when a sub-issue is labeled `spike`. A spike is a time-boxed
investigation whose deliverable is a *decision*, not a shipped feature.
This overlay **replaces** the Requirements and Acceptance criteria
sections with spike-specific fields: question, time-box, deliverable,
decision criteria.

The "Acceptance criteria" line `/implement` reads back is preserved by
keeping the deliverable as a checkable item. When the spike is complete,
the deliverable should be a written artifact (an ADR, a prototype branch,
a benchmark report) that another ticket can act on.

---

```markdown
## Context

<1–3 sentences: why this question is blocking other work, what assumption we're testing.>

## Question

<The single sentence the spike answers. If you can't write it as one sentence, the spike is too broad — split it.>

## Time-box

<Explicit hours or days cap, e.g. "2 days max". Going over = stop and reassess, not push through.>

## Deliverable

<What the spike produces. Be concrete:
- An ADR at `docs/adr/NNNN-<slug>.md`
- A prototype branch `spike/<slug>` with a README
- A benchmark report at `docs/benchmarks/<slug>.md`
- A written recommendation in this ticket's comments
>

## Decision criteria

What would make us pick option A vs option B vs walk away?

- <criterion> — <how we'd measure it>
- <criterion> — <how we'd measure it>

## Acceptance criteria

- [ ] Question is answered (yes / no / "we need more info, here's what")
- [ ] Deliverable exists at the path above
- [ ] Decision recorded — either an ADR is written, or a follow-up ticket is filed with the chosen approach
- [ ] Time-box was respected (or the overrun is documented with a reason)

## Implementation notes

<What to read first, what to prototype, what to measure. Files / docs / external sources.>

## Dependencies

- Blocked by: <ticket id, or "none">

## Spec

`specs/<file>.md` — or `none` if the spike pre-dates a spec.
```
