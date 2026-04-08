---
name: brainstorm
description: |
  Plan new features. Search Linear for duplicates, discuss breakdown with the user,
  and write a spec file. Use when: "brainstorm", "plan a feature", "new feature idea",
  "explore an idea".
model: opus
effort: medium
argument-hint: "[feature topic]"
allowed-tools:
  - Bash
  - Read
  - Write
  - Glob
  - Grep
  - AskUserQuestion
---

# /brainstorm — Plan New Features

## Preamble

Run this first:

```bash
# Resolve repo root from this skill's symlink target (./setup persists this).
if [ -z "${LINEAR_SDLC_ROOT:-}" ]; then
  for _candidate in "$HOME/.claude/skills/brainstorm/SKILL.md" \
                    "$HOME/.claude/skills/linear-sdlc-brainstorm/SKILL.md"; do
    if [ -L "$_candidate" ]; then
      LINEAR_SDLC_ROOT="$(cd "$(dirname "$(readlink "$_candidate")")/../.." && pwd)"
      break
    fi
  done
  if [ -z "${LINEAR_SDLC_ROOT:-}" ]; then
    LINEAR_SDLC_ROOT="$(lsdlc-config get source_dir 2>/dev/null || echo "")"
  fi
  export LINEAR_SDLC_ROOT
fi

# Source LINEAR_API_KEY for lsdlc-linear if it isn't already in the environment.
if [ -z "${LINEAR_API_KEY:-}" ] && [ -f "${LSDLC_STATE_DIR:-$HOME/.linear-sdlc}/env" ]; then
  set +u
  . "${LSDLC_STATE_DIR:-$HOME/.linear-sdlc}/env"
  set -u
fi

_BRANCH=$(git branch --show-current 2>/dev/null || echo "unknown")
_SLUG=$(lsdlc-slug 2>/dev/null | grep '^SLUG=' | cut -d= -f2 || basename "$(git rev-parse --show-toplevel 2>/dev/null || pwd)")
_PROJ="${HOME}/.linear-sdlc/projects/${_SLUG}"
mkdir -p "$_PROJ/checkpoints" "$_PROJ/wiki"

echo "BRANCH: $_BRANCH"
echo "PROJECT: $_SLUG"

_LEARN_FILE="$_PROJ/learnings.jsonl"
if [ -f "$_LEARN_FILE" ]; then
  _LEARN_COUNT=$(wc -l < "$_LEARN_FILE" | tr -d ' ')
  echo "LEARNINGS: $_LEARN_COUNT entries"
  [ "$_LEARN_COUNT" -gt 0 ] && lsdlc-learnings-search --limit 3 2>/dev/null || true
else
  echo "LEARNINGS: 0"
fi

_SESSION_ID="$$-$(date +%s)"
lsdlc-timeline-log '{"skill":"brainstorm","event":"started","branch":"'"$_BRANCH"'","session":"'"$_SESSION_ID"'"}' 2>/dev/null &

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

Search Linear for existing issues related to the topic via the bundled `lsdlc-linear` helper (direct GraphQL — no MCP needed):

```bash
TOPIC="rate limiting"  # substitute the actual topic
lsdlc-linear search-issues "$TOPIC" --limit 10
```

The output is JSON with `count` and `issues[]`. Parse it inline if you need specific fields:

```bash
TOPIC="rate limiting"
lsdlc-linear search-issues "$TOPIC" --limit 10 | node -e '
  const data = JSON.parse(require("fs").readFileSync(0, "utf8"));
  for (const i of data.issues) {
    console.log(`${i.identifier}\t${i.state.name}\t${i.title}`);
  }
'
```

- Search by keywords from the topic
- Linear's full-text search covers open and closed issues by default

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

Before diving into discussion, assess whether this feature needs **light mode** (jump to Step 4) or **deep-design mode** (run the expanded flow below, then continue to Step 5).

**Deep-design mode triggers** — enter it if ANY are true:
- The feature spans multiple independent subsystems (e.g., "build auth + billing + notifications")
- It requires architecture decisions (new services, data model changes, API design)
- It would benefit from visual mockups, wireframes, or architecture diagrams
- The user explicitly asks for a "full design" or "design spec"

**Light mode** (default) — stay in the normal flow if the feature is:
- A well-scoped enhancement or addition to existing functionality
- Clear enough to go straight from discussion to tickets
- Something the user wants to move quickly on without a formal design phase

### Deep-Design Mode (inline, no external skills)

Run these sub-steps in order. This replaces Step 4 when deep-design mode is active.

**3a. Project exploration.** Before proposing anything, ground the discussion in the actual codebase:
- Read `README.md` and `CLAUDE.md` if they exist
- List top-level directories (`ls -F`) to understand the project shape
- Glob `specs/*.md` and skim any existing specs — they reveal conventions and prior decisions
- Note what's missing: if you don't see what you expected (e.g. no tests, no docs for a module), that's signal

Tell the user what you found in 3-5 lines before moving on.

**3b. Propose 2-3 approaches.** Present them as a trade-off table, not prose. Example:

| Approach | Complexity | Blast radius | Migration cost | Future flexibility |
|---|---|---|---|---|
| A. Inline in existing service | Low | Medium | None | Low |
| B. New sidecar service | High | Low | Medium | High |
| C. Library shared across services | Medium | High | High | Medium |

Use `AskUserQuestion` to pick an approach. Recommend one and say why.

**3c. Chunked presentation.** Once an approach is picked, walk through the design **one section at a time**. Do not dump the whole design in one message. Pause for per-section approval via `AskUserQuestion` before moving to the next section. Sections, in order:

1. **Data model** — entities, relationships, new/changed tables or types
2. **API surface** — external interfaces, endpoints, function signatures users will see
3. **Failure modes** — what can go wrong, how the system degrades, retry/rollback strategy
4. **Rollout** — migration plan, feature flags, backwards compatibility, rollback path

For each section: describe it, show a diagram or code snippet if it helps, then ask "Looks good? Anything to adjust before the next section?"

**3d. Self-review checklist.** Before writing the spec file, walk through this checklist aloud with the user. If any item fails, fix it before continuing:

- [ ] Every acceptance criterion the user mentioned has a concrete home in the design
- [ ] No placeholder text, no `TODO`, no "we'll figure this out later"
- [ ] Open questions are explicitly listed in the spec (under "Open Questions"), not hidden
- [ ] Scope boundaries — what's explicitly **out** of V1 — are named

**3e. Continue to Step 5** (skip Step 4 — the deep-design flow already covered the discussion).

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
3. Read the template: `$LINEAR_SDLC_ROOT/templates/spec-template.md` (set by the preamble)
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
lsdlc-timeline-log '{"skill":"brainstorm","event":"completed","branch":"'"$_BRANCH"'","outcome":"DONE","spec":"specs/SLUG.md","session":"'"$_SESSION_ID"'"}' 2>/dev/null
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
