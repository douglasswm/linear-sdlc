# Persona template

Used by `/kickoff` Step 3 to author one or more personas under
`docs/personas/<slug>.md`. Referenced by `/brainstorm` (Personas section
in the spec template) and by user-story sub-issues
(`templates/issue-types/story.md`).

Personas are not optional, even for solo projects. "Me, six months from
now" is a valid persona — capturing your own future context is the point.

Claude fills in the `<...>` placeholders during the `/kickoff` discussion.
Omit a subsection only if the user has nothing to say there.

---

```markdown
# Persona: <name>

**Role:** <one-line role, e.g. "Backend engineer at a 10-person startup">
**Maturity:** Novice | Intermediate | Power user

## Context

<Where does this persona work? What tools do they already use? What does a typical day look like? 2–4 sentences.>

## Goals

- <Top thing they're trying to accomplish>
- <Top thing they're trying to accomplish>
- <Top thing they're trying to accomplish>

## Frustrations

- <Top thing that gets in their way today>
- <Top thing that gets in their way today>
- <Top thing that gets in their way today>

## Success criteria

<What does "this product worked for me" look like for this persona? One concrete sentence — the reader should be able to test it.>
```
