# Epic overlay

Applied **on top of** the parent issue shape in `templates/issue-template.md`
when a parent ticket is labeled `epic`. The base parent shape (Problem,
Goal, Scope, Out of scope, Spec) stays. This overlay adds the sections
that distinguish an epic — outcome, KPIs, personas served, milestones,
risks — so the parent ticket reads as a real piece of strategy rather
than a table-of-contents stub.

`/create-tickets` reads the base parent template plus this overlay when
the planned breakdown labels the parent `epic`. Sections from this
overlay are appended after `## Goal`, in the order shown below.

Same fill rules as the base template: write `none` rather than dropping
a heading if a section has genuinely nothing to say.

---

```markdown
## Outcome

<The user/business state once the epic ships. One paragraph. Concrete: "X users can do Y in under Z seconds" rather than "improved Y experience".>

## Success metrics

- <KPI> — current <baseline> → target <number> measured by <source>
- <KPI> — current <baseline> → target <number> measured by <source>

## Personas served

- <persona> — `docs/personas/<slug>.md` — <one-line on why this epic matters to them>
- <persona> — `docs/personas/<slug>.md` — <one-line on why this epic matters to them>

## Milestones

Phased delivery checkpoints. Each links to the sub-issue that delivers it.

- [ ] **<Milestone 1>** — VER-XX
- [ ] **<Milestone 2>** — VER-XX
- [ ] **<Milestone 3>** — VER-XX

## Risks

- <risk> — likelihood <low/med/high> / impact <low/med/high> / mitigation <how we'd handle it>
- <risk> — likelihood <low/med/high> / impact <low/med/high> / mitigation <how we'd handle it>
```
