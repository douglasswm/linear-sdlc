---
name: brainstorm
description: |
  Plan new features. Search Linear for duplicates, discuss breakdown with the user,
  and write a spec file. Use when: "brainstorm", "plan a feature", "new feature idea",
  "explore an idea".
model: opus
effort: high
allowed-tools:
  - Bash
  - Read
  - Write
  - Glob
  - Grep
  - Skill
  - AskUserQuestion
---

# /brainstorm — Plan New Features

## Preamble

Run this first:

```bash
_BRANCH=$(git branch --show-current 2>/dev/null || echo "unknown")
_SLUG=$(~/.claude/skills/linear-sdlc/bin/lsdlc-slug 2>/dev/null | grep '^SLUG=' | cut -d= -f2 || basename "$(git rev-parse --show-toplevel 2>/dev/null || pwd)")
_PROJ="${HOME}/.linear-sdlc/projects/${_SLUG}"
mkdir -p "$_PROJ/checkpoints" "$_PROJ/wiki"

echo "BRANCH: $_BRANCH"
echo "PROJECT: $_SLUG"

_LEARN_FILE="$_PROJ/learnings.jsonl"
if [ -f "$_LEARN_FILE" ]; then
  _LEARN_COUNT=$(wc -l < "$_LEARN_FILE" | tr -d ' ')
  echo "LEARNINGS: $_LEARN_COUNT entries"
  [ "$_LEARN_COUNT" -gt 0 ] && ~/.claude/skills/linear-sdlc/bin/lsdlc-learnings-search --limit 3 2>/dev/null || true
else
  echo "LEARNINGS: 0"
fi

_SESSION_ID="$$-$(date +%s)"
~/.claude/skills/linear-sdlc/bin/lsdlc-timeline-log '{"skill":"brainstorm","event":"started","branch":"'"$_BRANCH"'","session":"'"$_SESSION_ID"'"}' 2>/dev/null &

echo "---"
```

## Step 1: Understand the Feature

If the user provided a topic (e.g., `/brainstorm rate limiting`), use it as the starting point.

If no topic was provided, use AskUserQuestion:
```
**Re-ground:** Starting a brainstorm session to plan a new feature.

**Context:** Tell me what you'd like to build. A sentence or two is fine — we'll flesh it out together.
```

## Step 2: Search for Duplicates

Use the Linear MCP server to search for existing issues related to the topic:
- Search by keywords from the topic
- Check for both open and closed issues

If similar tickets exist, present them:
```
## Existing Related Tickets

| Ticket | Title | Status |
|--------|-------|--------|
| VER-30 | Basic rate limiting | Done |
| VER-41 | Rate limiting v2 | Backlog |

These look related. Want to:
1. **Build on VER-41** — enhance the existing ticket
2. **Create new** — this is different enough to be separate
3. **Cancel** — this is already covered
```

If no duplicates found, proceed.

## Step 3: Assess Complexity

Before diving into discussion, assess whether this feature needs a lightweight brainstorm or a full design process.

**Escalate to `superpowers:brainstorming`** if ANY of these are true:
- The feature spans multiple independent subsystems (e.g., "build auth + billing + notifications")
- It requires architecture decisions (new services, data model changes, API design)
- It would benefit from visual mockups, wireframes, or architecture diagrams
- The user explicitly asks for a "full design" or "design spec"

If escalating, tell the user:
```
This feature is complex enough to benefit from a full design process with architecture review,
approach trade-offs, and a formal spec. Handing off to the design brainstorming workflow.
```
Then invoke the `superpowers:brainstorming` skill. After it produces a design spec, return here and offer to run `/create-tickets` on it.

**Stay in `/brainstorm`** if the feature is:
- A well-scoped enhancement or addition to existing functionality
- Clear enough to go straight from discussion to tickets
- Something the user wants to move quickly on without a formal design phase

## Step 4: Guided Discussion

Walk through these questions with the user. Don't dump them all at once — have a conversation.

1. **Problem**: What problem are we solving? Who is affected?
2. **Impact**: What happens if we don't solve it? How urgent is this?
3. **Solution shape**: What should the solution look like from the user's perspective?
4. **Scope**: What's the minimum viable version? What's out of scope for V1?
5. **Technical approach**: At a high level, how would we build this?
6. **Breakdown**: Is this one ticket or multiple? What's the natural decomposition?

After each answer, reflect back your understanding and ask the next question. Don't assume — verify.

## Step 5: Write the Spec

Create the spec file:

1. Create `specs/` directory if it doesn't exist: `mkdir -p specs`
2. Generate a slug from the topic: `echo "rate-limiting" | tr ' ' '-' | tr -cd 'a-z0-9-'`
3. Read the template: `~/.claude/skills/linear-sdlc/templates/spec-template.md`
4. Fill in the template with the discussion results
5. Write to `specs/{slug}.md`

Present the spec to the user for review. Ask if they want to adjust anything.

## Step 6: Next Steps

After the spec is finalized:

```
**Re-ground:** Spec written to `specs/rate-limiting.md`.

**Next steps:**
1. **Create tickets now** — Run `/create-tickets specs/rate-limiting.md` to create Linear issues
2. **Review first** — Share the spec with the team before creating tickets
3. **Done for now** — We'll create tickets later

**Recommendation:** If this is ready to build, create tickets now while the context is fresh.
```

## Step 7: Wrap Up

```bash
~/.claude/skills/linear-sdlc/bin/lsdlc-timeline-log '{"skill":"brainstorm","event":"completed","branch":"'"$_BRANCH"'","outcome":"DONE","spec":"specs/SLUG.md","session":"'"$_SESSION_ID"'"}' 2>/dev/null
```

```
STATUS: DONE
SUMMARY: Brainstormed rate limiting feature, spec written to specs/rate-limiting.md
```

## Important Rules

1. **Don't rush the discussion.** The goal is to understand the feature deeply, not to generate a spec fast.
2. **Challenge assumptions.** If something sounds too broad, push for narrower scope. If it sounds too narrow, ask if there's a bigger picture.
3. **Search for duplicates first.** Don't waste time spec'ing something that already exists.
4. **The spec is a living document.** It doesn't need to be perfect — it needs to capture the key decisions.
