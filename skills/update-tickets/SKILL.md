---
name: update-tickets
description: |
  Refresh existing Linear issues so their descriptions match the structured
  issue-description template. Use when: "update tickets", "refresh tickets",
  "retemplate issues", "bring old tickets up to date", "fix stale descriptions".
model: sonnet
effort: medium
argument-hint: "[VER-42 | parent-id | path/to/spec.md]"
allowed-tools:
  - Bash
  - Read
  - Glob
  - AskUserQuestion
---

# /update-tickets — Refresh Linear Issues to the New Template

Issues created before the structured issue-description template landed are
usually one-liners with no `## Context` / `## Acceptance criteria` headings.
`/implement` can't plan against them — it reads the `Acceptance criteria`
checklist back as a binding contract. This skill walks selected issues,
reshapes their descriptions against `templates/issue-template.md`, shows a
diff, and pushes the refreshed description via `lsdlc-linear update-issue`.

Companion to `/create-tickets`: that skill handles fresh creation from a
spec, this one handles retrofitting issues that already exist.

## Preamble

Run this first:

```bash
# Bootstrap: resolve LINEAR_SDLC_ROOT from this skill's symlink, then source
# the shared preamble (safe env loader + project detection + session tracking).
if [ -z "${LINEAR_SDLC_ROOT:-}" ]; then
  for _c in "$HOME/.claude/skills/brainstorm/SKILL.md" \
            "$HOME/.claude/skills/linear-sdlc-brainstorm/SKILL.md"; do
    if [ -L "$_c" ]; then
      LINEAR_SDLC_ROOT="$(cd "$(dirname "$(readlink "$_c")")/../.." && pwd)"
      break
    fi
  done
  [ -z "${LINEAR_SDLC_ROOT:-}" ] && LINEAR_SDLC_ROOT="$(lsdlc-config get source_dir 2>/dev/null || true)"
  export LINEAR_SDLC_ROOT
fi
SKILL_NAME=update-tickets . "$LINEAR_SDLC_ROOT/references/preamble.sh"

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

## Step 1: Resolve Target Issues

The user invokes this as one of:

- `/update-tickets VER-42` — refresh a single issue
- `/update-tickets VER-40` — a parent issue; offer to walk its children
- `/update-tickets specs/foo.md` — find every issue whose description links this spec
- `/update-tickets` — no argument; print usage and exit DONE

Dispatch on the argument shape:

### 1a. Issue-ID mode (matches `^[A-Z]+-[0-9]+$`)

Fetch the issue and its children via the existing helper:

```bash
lsdlc-linear get-issue "$1"
```

The returned JSON includes `description`, `parent`, and
`children { nodes { identifier title state { name } } }` — everything this
skill needs to decide scope.

- **No children** → single-issue mode. One target: `$1`.
- **Has children** → it's a parent. Use `AskUserQuestion` with three options:
  1. **Parent + all children** (recommended) — refresh the entire subtree
  2. **Just the parent**
  3. **Just the children**

  Then build the target list accordingly.

### 1b. Spec-path mode (arg ends in `.md` and file exists)

Use `lsdlc-linear search-issues` with the spec's bare filename, then
filter client-side by issues whose `description` literally contains the
spec path. Present the candidates and confirm before proceeding:

```bash
SPEC_PATH="$1"
SPEC_BASENAME=$(basename "$SPEC_PATH")
lsdlc-linear search-issues "$SPEC_BASENAME" --limit 50 | node -e '
  const d = JSON.parse(require("fs").readFileSync(0, "utf8"));
  const want = process.argv[1];
  for (const i of d.issues || []) {
    if ((i.description || "").includes(want)) {
      console.log([i.identifier, i.title].join("\t"));
    }
  }
' "$SPEC_PATH"
```

Show the matched list and use `AskUserQuestion` to confirm:
**Refresh all** / **Pick a subset** / **Cancel**.

### 1c. No argument

Print usage, log timeline completion with `outcome: NO_TARGET`, exit with
`STATUS: DONE` and a `SUMMARY:` that explains the supported argument
shapes.

## Step 2: Load the Template Once

Read `$LINEAR_SDLC_ROOT/templates/issue-template.md` **once** at the start
of Step 2. It defines two shapes — parent and sub-issue — plus the
rationale for each section. Every refresh in Step 4 must fill this
template shape exactly. This is the same file `/create-tickets` reads at
its Step 4a, keeping both skills in lockstep.

## Step 3: Detect Staleness and Pick Source Material

For each target issue, fetch its full detail (if you don't already have
it from Step 1) and run two checks:

### 3a. Stale test

Decide whether the issue is already on-template:

- **Parent shape** (issue's `parent` field is null): expected headings
  `## Problem`, `## Goal`, `## Scope`.
- **Sub-issue shape** (`parent` is set): expected headings `## Context`,
  `## Acceptance criteria`, and the acceptance criteria block must contain
  at least one `- [ ]` or `- [x]` line.

If every expected heading is present **and** (for sub-issues) the
acceptance criteria block is non-empty, mark the issue `skipped
(already on-template)` and do not draft a refresh. This makes re-runs
safe.

### 3b. Source material resolution

For issues that need a refresh, pick the content source in this order:

1. **Linked spec.** If the current description contains a `` ## Spec ``
   section with a `` `specs/<path>.md` `` reference, try to `Read` that
   file. If it exists, use it as the primary source.
2. **User-supplied spec.** If Step 1 was invoked in spec-path mode, that
   spec is the source for every matched issue.
3. **Existing description fallback.** Otherwise, reshape whatever text is
   already on the issue into the template. When falling back, **call this
   out in Step 5's confirmation prompt** — the user needs to know no new
   information is being introduced.

## Step 4: Draft the Refreshed Description

For each non-skipped target, draft a full description that follows
`templates/issue-template.md`. Copy the rules `/create-tickets` enforces
at its Step 4a:

- **Never drop a heading.** If a section genuinely has nothing to say,
  write `none` — do not omit the heading itself.
- **Never summarize the acceptance criteria.** Every criterion is a
  testable `- [ ]` line. A sub-issue without a concrete checklist is
  broken; `/implement` reads it back later.
- **Preserve existing content.** If the stale description already has a
  non-empty acceptance-criteria block, carry every criterion forward.
  Only add new criteria if the spec dictates them. Never silently drop
  or reword an existing criterion — if one is wrong, surface it in Step
  5 and let the user decide.
- **Titles are left alone by default.** Only draft a title change if the
  current title has a clear bug (typo, wrong prefix). Title drift is not
  something this skill fixes.
- **Parent vs sub-issue shape** is determined by the issue's `parent`
  field, not by the argument the user passed.

Hold each draft in memory (or a scratch variable) until Step 5 confirms
it.

## Step 5: Confirm Per Issue

Before mutating anything, show the user the diff one issue at a time:

```
## VER-42 — Rate limiter middleware
Source: specs/rate-limiting.md
Shape: sub-issue

### Before
Redis-based sliding window, configurable per-endpoint

### After
## Context
Foundation ticket for the rate limiting epic. Introduces the shared
middleware all other sub-issues wire into.

## Requirements
- Redis-backed sliding window counter
- Per-endpoint configurable limits (requests + window)

## Acceptance criteria
- [ ] Middleware rejects requests over the configured limit with HTTP 429
- [ ] Limits are configurable per route without a code change
- [ ] Counter state survives process restarts (Redis-backed, not in-memory)
- [ ] Unit tests cover the sliding-window math and the over-limit path

## Implementation notes
Lives in `src/middleware/rate-limit.ts`. Reuse the existing Redis client
from `src/lib/redis.ts`.

## Dependencies
- Blocked by: none

## Spec
`specs/rate-limiting.md`
```

If the source is the existing description (fallback path), say so
explicitly above the diff:

```
Source: existing description (fallback — no new information)
```

Then use `AskUserQuestion`:

```
**Re-ground:** Refresh VER-42's description with the block above? This
overwrites the Linear description field.

**Options:**
1. **Apply** — Push this refresh to Linear (recommended)
2. **Apply all remaining** — Apply this and every remaining draft without
   further prompting
3. **Skip this one** — Leave VER-42 alone, continue to the next draft
4. **Cancel** — Stop here, do not apply any remaining drafts

**Recommendation:** Apply — review the acceptance criteria carefully;
they're the contract `/implement` will verify later.
```

Recommend **Apply** for the first draft. Once the user has seen one
clean diff and trusts the output, **Apply all remaining** is a
reasonable default for subsequent drafts — switch the recommendation
then.

## Step 6: Push the Approved Updates

Run **all approved updates inside a single Bash tool call** so the
`mktemp -d` staging directory (and its `trap 'rm -rf' EXIT`) stays alive
across every push. Use single-quoted heredoc sentinels
(`<<'DESC1_EOF'`) so markdown characters — `` ` ``, `$`, `#`, `[`,
backslashes — pass through to Linear literally. This is the same safety
rule `/create-tickets` Step 4b enforces.

```bash
TMPD=$(mktemp -d)
trap 'rm -rf "$TMPD"' EXIT

# One heredoc per approved draft. Write each to its own temp file,
# then call update-issue with --description-file.
cat <<'DESC1_EOF' > "$TMPD/ver-42.md"
## Context
Foundation ticket for the rate limiting epic. Introduces the shared
middleware all other sub-issues wire into.

## Requirements
- Redis-backed sliding window counter
- Per-endpoint configurable limits (requests + window)

## Acceptance criteria
- [ ] Middleware rejects requests over the configured limit with HTTP 429
- [ ] Limits are configurable per route without a code change
- [ ] Counter state survives process restarts (Redis-backed, not in-memory)
- [ ] Unit tests cover the sliding-window math and the over-limit path

## Implementation notes
Lives in `src/middleware/rate-limit.ts`. Reuse the existing Redis client
from `src/lib/redis.ts`.

## Dependencies
- Blocked by: none

## Spec
`specs/rate-limiting.md`
DESC1_EOF
lsdlc-linear update-issue VER-42 --description-file "$TMPD/ver-42.md"

# Repeat the heredoc / update-issue pair for every approved draft.
```

If the user approved a title change for any issue, add `--title "..."` to
that issue's `update-issue` call. Both flags can be passed in the same
invocation.

## Step 7: Summary

Present what happened:

```
## Refreshed Tickets

| Ticket | Title                              | Outcome                         |
|--------|------------------------------------|---------------------------------|
| VER-42 | Rate limiter middleware            | refreshed                       |
| VER-43 | Apply rate limiting to auth        | refreshed                       |
| VER-44 | Rate limit response headers        | skipped (already on-template)   |
| VER-45 | Rate limiting dashboard            | skipped (user)                  |

**Template:** `templates/issue-template.md`
**Next step:** Re-run `/next` or `/implement <ID>` on any refreshed
ticket — the acceptance-criteria checklist is now in place for planning.
```

Outcome vocabulary:
- `refreshed` — description (and optionally title) updated in Linear
- `skipped (already on-template)` — Step 3a marked it clean
- `skipped (user)` — user picked "Skip this one" in Step 5
- `failed` — `update-issue` returned a non-success response; include the error

## Step 8: Wrap Up

```bash
lsdlc-timeline-log '{"skill":"update-tickets","event":"completed","branch":"'"$_BRANCH"'","outcome":"DONE","issues_refreshed":N,"issues_skipped":M,"session":"'"$_SESSION_ID"'"}' 2>/dev/null
```

```
STATUS: DONE
SUMMARY: Refreshed N Linear issues to the new template (M skipped)
```

## Important Rules

1. **Always confirm per issue before mutating.** No silent batch updates.
   "Apply all remaining" in Step 5 is an explicit opt-in after the user
   has seen at least one diff.
2. **Never drop an existing non-empty acceptance-criteria checklist.**
   Preserve every criterion verbatim; add new ones only if the spec
   dictates. If a criterion looks wrong, surface it in Step 5 and let the
   user decide — do not silently rewrite.
3. **Every refreshed description follows `templates/issue-template.md`.**
   Parent shape: Problem / Goal / Scope / Out of scope / Spec. Sub-issue
   shape: Context / Requirements / Acceptance criteria / Implementation
   notes / Dependencies / Spec. Sub-issue vs parent is decided by the
   issue's own `parent` field, not the argument the user passed.
4. **Skip issues that already match the template.** Re-runs must be
   safe — stale detection in Step 3a is the guard. If a user really
   wants to re-refresh an already-on-template issue, they can edit the
   description in Linear first and re-run.
5. **Link back to the spec.** Every refreshed description's `## Spec`
   section references a spec file path — use the linked spec when
   available, the user-supplied spec otherwise, or `none` as a last
   resort.
