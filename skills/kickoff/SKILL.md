---
name: kickoff
description: |
  Day-zero project kickoff. Author docs/CHARTER.md and 1–3 personas under
  docs/personas/ from a guided discussion. Use when: "kickoff", "start a new
  project", "new project", "project charter", "set up a new repo".
model: opus
effort: medium
argument-hint: "[project name]"
allowed-tools:
  - Bash
  - Read
  - Write
  - Glob
  - Grep
  - AskUserQuestion
---

# /kickoff — Day-Zero Project Charter

This skill runs **once** at the start of a new project. It produces two
durable artifacts that every later skill reads:

- `docs/CHARTER.md` — vision, target users, success metrics, constraints, MVP, non-goals, tech sketch, risks, open questions
- `docs/personas/<slug>.md` — one file per persona discussed

When this finishes, the user runs `/brainstorm <first MVP item>` to spec
the first feature. `/brainstorm` Step 1.5 will read the charter you wrote
and ground the spec discussion in it.

## Preamble

Run this first:

```bash
# Bootstrap: resolve LINEAR_SDLC_ROOT from this skill's symlink, then source
# the shared preamble (safe env loader + project detection + session tracking).
if [ -z "${LINEAR_SDLC_ROOT:-}" ]; then
  for _c in "$HOME/.claude/skills/kickoff/SKILL.md" \
            "$HOME/.claude/skills/linear-sdlc-kickoff/SKILL.md"; do
    if [ -L "$_c" ]; then
      LINEAR_SDLC_ROOT="$(cd "$(dirname "$(readlink "$_c")")/../.." && pwd)"
      break
    fi
  done
  [ -z "${LINEAR_SDLC_ROOT:-}" ] && LINEAR_SDLC_ROOT="$(lsdlc-config get source_dir 2>/dev/null || true)"
  export LINEAR_SDLC_ROOT
fi
SKILL_NAME=kickoff . "$LINEAR_SDLC_ROOT/references/preamble.sh"

# Learnings (skill-specific display)
_LEARN_FILE="$_PROJ/learnings.jsonl"
if [ -f "$_LEARN_FILE" ]; then
  _LEARN_COUNT=$(wc -l < "$_LEARN_FILE" | tr -d ' ')
  echo "LEARNINGS: $_LEARN_COUNT entries"
  [ "$_LEARN_COUNT" -gt 0 ] && lsdlc-learnings-search --limit 3 2>/dev/null || true
else
  echo "LEARNINGS: 0"
fi

echo "---"
```

## Step 1: Project basics + idempotency check

If `docs/CHARTER.md` already exists, this is not day zero. Use
`AskUserQuestion`:

```
**Re-ground:** docs/CHARTER.md already exists — kickoff has run before.

**Context:** Kickoff is a one-time skill. Re-running it would either
overwrite your charter or duplicate work.

**Options:**
1. **Edit the existing charter** — open it for review and walk through any sections that need updating (recommended)
2. **Archive and start fresh** — move the existing charter to `docs/CHARTER.archived-YYYY-MM-DD.md` and begin a new one
3. **Cancel** — exit without changes

**Recommendation:** Option 1 unless the project's direction has fundamentally changed.
```

If charter does not exist, gather the basics:

- **Project name** — from the slash-command argument if provided, else ask
- **Owner** — defaults to `git config user.name`, ask if missing
- **One-line description** — what this project is, in one sentence

Reflect back what you heard before moving on.

## Step 2: Vision

Ask for one paragraph: what does the world look like once this project
exists? Push for concrete imagery, not corporate aspiration. The reader
should be able to picture a user benefiting from it.

After the user answers, restate it in your own words and ask if you
captured it. Iterate until they say yes.

## Step 3: Personas (inline authoring)

Walk through 1–3 personas. For each, ask:

1. **Role** — one line, e.g. "Backend engineer at a 10-person startup"
2. **Maturity** — Novice / Intermediate / Power user
3. **Context** — where they work, what tools they use, what their day looks like
4. **Goals** — top 3 things they're trying to accomplish
5. **Frustrations** — top 3 things that get in their way today
6. **Success criteria** — one concrete sentence: "this product worked for me when..."

After each persona is captured, **read the persona template once**:
`$LINEAR_SDLC_ROOT/templates/persona-template.md`. Fill it in. Use
`AskUserQuestion` to confirm before writing:

```
**Re-ground:** Persona "{name}" captured.

**Context:** I'll write this to `docs/personas/{slug}.md`. You can edit it later.

**Options:**
1. **Write it** — save the persona file and continue (recommended)
2. **Edit first** — show me what to change before writing
3. **Skip this persona** — drop it from the charter
```

Then write the file. After all personas are done, summarize: "Captured
N personas under docs/personas/."

**Personas are not optional.** Even for solo projects, "me, six months
from now" is a valid persona — capturing your own future context is the
point. Push back if the user says "no personas needed".

## Step 4: Success metrics + constraints

Ask for 1–3 measurable outcomes. Each needs:

- The metric itself
- A target number
- A measurement source (analytics tool, log query, manual count, etc.)

Push back on vague metrics. "Users love it" is not measurable; "weekly
active users / monthly active users > 0.5 measured by Mixpanel" is.

Then ask about constraints:

- **Budget** — amount or "none"
- **Timeline** — target ship date or "open-ended"
- **Team** — size and roles
- **Compliance** — SOC2, HIPAA, GDPR, none
- **Platform** — web, iOS, server, etc.

## Step 5: MVP + non-goals

Ask: "What is the smallest cut that proves the vision?" Push for the
*smallest* cut. If they list 10 capabilities, ask which 3 are
non-negotiable.

Then ask the inverse: "What are we deliberately not doing?" This is
broader than per-feature out-of-scope — it's the long-term shape of the
project. Capture as the **Non-goals** list.

## Step 6: Tech-stack sketch

Ask for the current thinking on:

- Language / runtime
- Framework
- Hosting
- Storage

Capture as one-liners. **Do not author ADRs here.** If the user has a
real tech decision that needs justification, note it as a TODO ADR in
the open questions list — ADRs belong in `/brainstorm` deep-design mode
where the trade-off table already lives.

If the user says "I haven't decided yet", write `TBD` for that line and
move on. This is a sketch, not a commitment.

## Step 7: Risks + open questions

Ask for the top 3 risks. For each:

- The risk itself
- Likelihood: low / med / high
- Impact: low / med / high
- Mitigation: how would you handle it if it happens

Then ask: "What questions came up during this discussion that we couldn't
answer?" Capture as `- [ ]` items.

## Step 8: Write the charter

```bash
mkdir -p docs docs/personas
```

Read the charter template:

```bash
cat "$LINEAR_SDLC_ROOT/templates/charter-template.md"
```

Fill in every `<...>` placeholder from steps 1–7. Sections with no input
get `none` (for lists) or `TBD` (for stack lines that the user explicitly
deferred). Never emit an empty heading.

Write the filled charter to `docs/CHARTER.md` using the Write tool.

Then read it back and show the user the rendered file:

```
## Charter written to docs/CHARTER.md

[show the full contents]
```

Ask if they want any edits before moving on.

## Step 9: Handoff

Use this closing block (per `references/ask-user-format.md`):

```
**Re-ground:** Charter written to `docs/CHARTER.md`. {N} personas under `docs/personas/`.

**Context:** Kickoff is done. The next move is to spec the first MVP feature while everything is fresh in memory.

**Next steps:**
1. **`/brainstorm <first MVP item>`** — spec the first feature now (recommended). Brainstorm will read the charter automatically.
2. **Review the charter with the team** — share `docs/CHARTER.md` before going further.
3. **Done for now** — pick this up later. Run `/brainstorm` whenever you're ready.

**Recommendation:** Option 1 — the context cost of resuming this later is real. If the team needs to weigh in, do option 2 first, then circle back to option 1.
```

Do **not** auto-invoke `/brainstorm`. The user runs it explicitly.

## Step 10: Wrap up

```bash
lsdlc-timeline-log '{"skill":"kickoff","event":"completed","branch":"'"$_BRANCH"'","outcome":"DONE","charter":"docs/CHARTER.md","session":"'"$_SESSION_ID"'"}' 2>/dev/null
```

```
STATUS: DONE
SUMMARY: Project chartered. docs/CHARTER.md + N personas written. Next: /brainstorm <first MVP item>.
```

## Error handling

If charter or persona write fails (Step 3 or Step 8), capture it as a
learning before reporting BLOCKED:

```bash
_lsdlc_capture_error kickoff "step-8" "charter-write-failed" "Could not write docs/CHARTER.md: <reason>. Check that docs/ is writable and that no editor has the file open."
```

Then report:

```
STATUS: BLOCKED
BLOCKER: Could not write docs/CHARTER.md — {one-line reason}
SUGGESTION: Check filesystem permissions on docs/, then re-run /kickoff.
```

## Important Rules

1. **Don't rush.** Kickoff is read by every later skill. Getting the
   vision wrong ripples for the life of the project.
2. **Challenge vague vision statements.** "Make X better" is not a
   vision. Push for one concrete sentence with imagery.
3. **Personas are not optional.** Even solo projects benefit from
   capturing "me, six months from now".
4. **Sketch, don't decide, on tech stack.** Real decisions get an ADR
   in `/brainstorm` deep-design mode, not here.
5. **Idempotent on re-run.** Never silently overwrite an existing
   `docs/CHARTER.md`.
6. **Hand off, don't chain.** End with a recommendation to run
   `/brainstorm` — let the user decide when.
