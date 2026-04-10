# Feature: {title}

**Author:** {author}
**Date:** {date}
**Status:** Draft | Review | Approved

---

## Problem

What problem are we solving? Who is affected? What happens if we don't solve it?

## Solution

High-level description of the proposed solution. What will change from the user's perspective?

## User Stories

- As a {role}, I want to {action} so that {benefit}.
- ...

## Technical Approach

### Architecture

How does this fit into the existing system? What components are affected?

### Data Model

Any new tables, fields, or schema changes?

### API Changes

New or modified endpoints?

### Dependencies

External services, libraries, or other tickets that must be completed first?

## Open Questions

- [ ] Question 1
- [ ] Question 2

## Acceptance Criteria

- [ ] Criterion 1
- [ ] Criterion 2
- [ ] Criterion 3

## Out of Scope

What are we explicitly NOT doing in this iteration?

---

The sections below are **optional**. Include them when the work is
greenfield or strategically important; omit them for routine feature
adds. `/brainstorm` decides whether to fill them based on the discussion
and on whether `docs/CHARTER.md` exists.

## Personas *(optional)*

Who is this for? Link to one or more persona files, or describe inline
if the project does not yet maintain `docs/personas/`.

- [<persona name>](../docs/personas/<slug>.md)
- *Or:* {role} — {one-line context}

## Success metrics *(optional)*

How will we know this worked? One to three measurable outcomes with a
target number and a measurement source.

- {metric} — target {number} measured by {source}

## Non-goals *(optional)*

Broader than "Out of Scope". Out of Scope is what we're deferring from
*this iteration*; Non-goals are things this feature deliberately will
*never* do.

- {thing this feature deliberately will not do}

## Risks & assumptions *(optional)*

- **Risk:** {what could go wrong} — {mitigation}
- **Assumption:** {what we're betting on} — {how we'd know if it's wrong}

## Rollout *(optional)*

How does this ship safely?

- **Feature flag:** {flag name, default state}
- **Rollout %:** {staged percentages or "all at once"}
- **Migration:** {data or schema migrations needed}
- **Rollback path:** {how we revert if things go sideways}
