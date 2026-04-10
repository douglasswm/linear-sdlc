# Architecture Decision Record template

Used by `/brainstorm` deep-design mode when a structural decision needs
durable justification. Written to `docs/adr/NNNN-<slug>.md` where `NNNN`
is the next zero-padded sequence number (e.g. `0001-postgres-over-mysql.md`).
The charter's "Tech stack" section gives one-line sketches; ADRs carry
the trade-offs and reasoning.

ADRs are immutable once accepted. To revise a decision, write a new ADR
that supersedes the old one and update the old one's `Status:` line to
`Superseded by ADR-NNNN`.

Claude fills in the `<...>` placeholders. Omit a section only if it
genuinely has nothing to say — never emit an empty heading.

---

```markdown
# ADR-<NNNN>: <title>

**Status:** Proposed | Accepted | Superseded by ADR-<NNNN>
**Date:** <YYYY-MM-DD>
**Deciders:** <names>

## Context

<What is the situation? What forces are at play? What constraints made this decision necessary now? 2–4 sentences. The reader six months from now needs to understand why this came up.>

## Decision

<What did we decide? One paragraph. Direct, declarative: "We will use X.">

## Alternatives considered

- **<Option A>** — <one sentence on what it is>
  - Pros: <…>
  - Cons: <…>
  - Why not: <one sentence>
- **<Option B>** — <one sentence on what it is>
  - Pros: <…>
  - Cons: <…>
  - Why not: <one sentence>

## Consequences

- **Positive:** <what gets easier / faster / safer>
- **Negative:** <what gets harder / slower / costlier — be honest>
- **Follow-ups:** <tickets we now need to file, e.g. VER-XX for migration, VER-YY for monitoring>
```
