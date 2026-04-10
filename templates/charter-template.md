# Project charter template

Used by `/kickoff` (`skills/kickoff/SKILL.md`) on day zero of a new project.
Written once to `docs/CHARTER.md`. Read by every later skill: `/brainstorm`
Step 1.5 grounds the spec discussion in the charter's vision and non-goals;
`/create-tickets` and `/implement` reference it implicitly through the spec
files that descend from it.

Claude fills in the `<...>` placeholders during the `/kickoff` discussion.
Omit a section only if the user says it genuinely does not apply — do not
emit empty headings. For sections that have nothing yet (e.g. tech stack
on day zero before any decision), write `TBD` rather than dropping the
heading, so the structure stays scannable.

---

```markdown
# Project: <name>

**Owner:** <name>
**Started:** <YYYY-MM-DD>
**Status:** Draft | Active | Sunset

## Vision

<One paragraph: what does the world look like once this project exists? Concrete, not aspirational. The reader should be able to picture a user benefiting from it.>

## Target users

- <persona name> — `docs/personas/<slug>.md`
- <persona name> — `docs/personas/<slug>.md`

## Success metrics

- <metric> — target <number> measured by <source>
- <metric> — target <number> measured by <source>

## Constraints

- **Budget:** <amount or "none">
- **Timeline:** <target ship date or "open-ended">
- **Team:** <size and roles>
- **Compliance:** <SOC2, HIPAA, GDPR, none>
- **Platform:** <web, iOS, server, etc.>

## MVP

The smallest cut that proves the vision. Bullet list of capabilities.

- <capability>
- <capability>
- <capability>

## Non-goals

Explicit "not in V1" list. Protects scope for the whole project, not one feature.

- <thing we are deliberately not doing>
- <thing we are deliberately not doing>

## Tech stack (initial sketch)

- **Language / runtime:** <e.g. TypeScript / Node 20>
- **Framework:** <e.g. Next.js 14>
- **Hosting:** <e.g. Vercel + Supabase>
- **Storage:** <e.g. Postgres>

Real decisions get an ADR under `docs/adr/NNNN-<slug>.md`. This section is
the one-line sketch; the ADRs carry the trade-offs.

## Risks

- <risk> — likelihood <low/med/high> / impact <low/med/high> / mitigation <how we'd handle it>
- <risk> — likelihood <low/med/high> / impact <low/med/high> / mitigation <how we'd handle it>

## Open questions

- [ ] <question we couldn't answer during kickoff>
- [ ] <question we couldn't answer during kickoff>
```
