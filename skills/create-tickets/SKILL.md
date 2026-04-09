---
name: create-tickets
description: |
  Convert a spec file into Linear issues with parent/child relationships and
  dependencies. Use when: "create tickets", "make issues", "spec to tickets",
  "break this down into tickets".
model: sonnet
effort: medium
argument-hint: "[path/to/spec.md]"
allowed-tools:
  - Bash
  - Read
  - Glob
  - AskUserQuestion
---

# /create-tickets — Spec to Linear Issues

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
SKILL_NAME=create-tickets . "$LINEAR_SDLC_ROOT/references/preamble.sh"

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

## Step 1: Load the Spec

The user invokes this as `/create-tickets specs/rate-limiting.md` or `/create-tickets`.

If a spec file path is provided, read it.

If no path is provided:
1. Look for spec files: `ls specs/*.md 2>/dev/null`
2. If specs exist, present them and ask which to use
3. If no specs exist, suggest running `/brainstorm` first

Read and parse the spec file. Extract:
- **Feature title** (from the `# Feature:` heading)
- **Problem statement** (from the Problem section)
- **User stories** (from the User Stories section)
- **Technical approach** (from the Technical Approach section)
- **Acceptance criteria** (from the Acceptance Criteria section)

## Step 1b: Scope Check

Before planning the ticket breakdown, scan the spec for scope sprawl. If the work touches **many subsystems**, the right granularity may be multiple parent issues rather than one.

Heuristic:
1. Count distinct subsystems mentioned in the spec. A subsystem is any top-level `##`/`###` heading that names a service, module, or area (e.g. "Auth", "Billing", "Notifications"), plus any explicit service/module names in the technical approach.
2. If **≥ 3 distinct subsystems** are touched and the user hasn't already explicitly asked for one parent, ask:

```
**Re-ground:** This spec touches {N} subsystems: {comma-separated list}.

**Context:** Bundling all of this under one parent works if it ships together; splitting
into separate parents works better if each subsystem can ship independently.

**Options:**
1. **One parent with sub-issues** — recommended if everything ships as one release
2. **{N} separate parent issues** — recommended if each subsystem can ship independently
3. **Proceed as-is** — you decide the breakdown in the next step
```

Respect the user's choice and carry it into Step 2. If fewer than 3 subsystems, skip this check and go straight to Step 2.

## Step 2: Plan the Ticket Breakdown

Analyze the spec and propose a ticket structure:

1. **Parent issue** — The feature/epic level ticket
2. **Sub-issues** — Individual implementable tickets
3. **Dependencies** — Which sub-issues must be completed before others

Guidelines for breakdown:
- Each sub-issue should be completable in 1-3 sessions
- Each sub-issue should have clear acceptance criteria. Draft at least 2–3 testable criteria per sub-issue during the breakdown — these become the `Acceptance criteria` checklist in the Linear description and the contract `/implement` checks against.
- Identify the critical path (what must be done first)
- Group related work (don't split a natural unit across tickets)

## Step 3: Confirm with User

Present the proposed breakdown **with the full acceptance-criteria checklist for every sub-issue**. This is the user's only chance to review the contract before it lands in Linear — `/implement` treats these criteria as binding in downstream steps, so they must be visible here, not summarized to a one-liner.

Use the per-ticket block format below (not a markdown table — tables can't fit a multi-item checklist cleanly):

```
## Ticket Breakdown: Rate Limiting

### Parent Issue
**Rate Limiting System** — Implement rate limiting across API endpoints
- Priority: High
- Labels: backend, security

### Sub-Issue 1: Rate limiter middleware
- Priority: High
- Blocked by: none
- Acceptance criteria:
  - [ ] Middleware rejects requests over the configured limit with HTTP 429
  - [ ] Limits are configurable per route without a code change
  - [ ] Counter state survives process restarts (Redis-backed, not in-memory)
  - [ ] Unit tests cover the sliding-window math and the over-limit path

### Sub-Issue 2: Apply rate limiting to auth endpoints
- Priority: High
- Blocked by: Sub-Issue 1
- Acceptance criteria:
  - [ ] Login, register, and password reset return 429 after the configured threshold
  - [ ] Limits are tuned per endpoint, not inherited from the global default
  - [ ] Integration test hits each endpoint repeatedly and asserts the 429

### Sub-Issue 3: Rate limit response headers
- Priority: Medium
- Blocked by: Sub-Issue 1
- Acceptance criteria:
  - [ ] Every response includes `X-RateLimit-Limit`, `X-RateLimit-Remaining`, `X-RateLimit-Reset`
  - [ ] Headers reflect the actual per-endpoint config, not a global default
  - [ ] Contract test locks the header names and formats

### Sub-Issue 4: Rate limiting dashboard
- Priority: Low
- Blocked by: Sub-Issues 1, 2
- Acceptance criteria:
  - [ ] Admin view lists current rate-limit state per endpoint and client
  - [ ] View is gated behind the existing admin auth middleware
```

The acceptance criteria shown here must be **identical** to what will land in the Linear description in Step 4 — do not rewrite or expand them between Step 3 and Step 4. If the user asks to adjust a criterion in the "Adjust" path, loop back through Step 3 and re-present the updated block before proceeding.

Use AskUserQuestion:
```
**Re-ground:** Ready to create 4 tickets in Linear (1 parent + 3 sub-issues). The acceptance criteria above are the contract `/implement` will verify later — review them now.

**Options:**
1. **Create all** — Create these tickets as shown (recommended)
2. **Adjust** — Modify the breakdown or acceptance criteria before creating
3. **Cancel** — Don't create tickets yet

**Recommendation:** Create all — we can always adjust tickets in Linear after creation, but acceptance criteria are much cheaper to fix now than mid-implementation.
```

## Step 4: Create in Linear

### 4a. Read the issue description template

Every Linear issue this skill creates uses the shape defined in
`$LINEAR_SDLC_ROOT/templates/issue-template.md`. Read that file **once** at the
start of Step 4 — it contains the parent and sub-issue templates plus the
rationale for each section. Draft every ticket's description by filling in the
placeholders against the spec and the breakdown approved in Step 3.

**Do not skip sections or inline one-line descriptions.** A sub-issue without a
concrete `Acceptance criteria` checklist breaks `/implement`, which reads that
checklist back when planning and verifying. If a section genuinely has nothing
to say (e.g. an independent ticket has no `Blocked by`), write `none` rather
than dropping the heading.

### 4b. Run the creation in a single bash tool call

Run **all of Step 4b inside a single Bash tool call** — bash variables (like `$PARENT_ID`, `$CHILD1_ID`) do NOT persist across separate Bash tool calls. If you split this into multiple tool calls, the parent/child references will be empty and you will create orphaned issues.

The pattern is: draft each description as a heredoc → create parent → capture id → create each child with `--parent "$PARENT_ID"` → capture each child id → call `add-relation` for each blocking edge. All in one shell session.

Linear priority numbers: `0` = no priority, `1` = urgent, `2` = high, `3` = medium, `4` = low.

**Heredoc safety:** always use single-quoted sentinels (`<<'PARENT_DESC_EOF'`), not bare ones. Single quotes disable shell interpolation so markdown characters — `` ` ``, `$`, `#`, `[`, backslashes — are passed through to Linear literally. A bare heredoc would try to expand `$foo` inside the description and corrupt it.

Template (substitute the actual title/description/priority/labels for each ticket from the breakdown approved in Step 3; the description bodies below are illustrative and must follow `templates/issue-template.md`):

```bash
TEAM=$(lsdlc-config get linear_team_id)

# 1. Parent description — follows the "Parent issue template" in templates/issue-template.md.
PARENT_DESC=$(cat <<'PARENT_DESC_EOF'
## Problem
Public API endpoints accept unlimited requests per client, leaving auth endpoints vulnerable to brute force and the service vulnerable to accidental traffic spikes from buggy integrations.

## Goal
Every public API endpoint enforces a per-client rate limit backed by Redis, with clear `X-RateLimit-*` headers and an admin view for operators.

## Scope
- Rate limiter middleware
- Apply rate limiting to auth endpoints
- Rate limit response headers
- Rate limiting dashboard

## Out of scope
- Per-plan / per-tier rate limits (follow-up)
- Distributed rate limiting across regions

## Spec
`specs/rate-limiting.md`
PARENT_DESC_EOF
)
PARENT_JSON=$(lsdlc-linear create-issue \
  --team "$TEAM" \
  --title "Rate Limiting System" \
  --description "$PARENT_DESC" \
  --priority 2 \
  --labels "backend,security")
PARENT_ID=$(printf '%s' "$PARENT_JSON" | node -e 'const j=JSON.parse(require("fs").readFileSync(0,"utf8")); process.stdout.write(j.issue.identifier)')
echo "Created parent: $PARENT_ID"

# 2. Sub-issue descriptions — one heredoc per child, each following the
#    "Sub-issue template" in templates/issue-template.md. Repeat the
#    CHILDn_DESC / CHILDn_JSON / CHILDn_ID triple for every sub-issue.
CHILD1_DESC=$(cat <<'CHILD1_DESC_EOF'
## Context
Foundation ticket for the rate limiting epic. Introduces the shared middleware all other sub-issues wire into.

## Requirements
- Redis-backed sliding window counter
- Per-endpoint configurable limits (requests + window)
- Middleware hook that returns 429 with `Retry-After` when the limit is exceeded

## Acceptance criteria
- [ ] Middleware rejects requests over the configured limit with HTTP 429
- [ ] Limits are configurable per route without a code change
- [ ] Counter state survives process restarts (Redis-backed, not in-memory)
- [ ] Unit tests cover the sliding-window math and the over-limit path

## Implementation notes
Lives in `src/middleware/rate-limit.ts`. Reuse the existing Redis client from `src/lib/redis.ts`. See the Technical Approach section of the spec for the sliding-window algorithm.

## Dependencies
- Blocked by: none

## Spec
`specs/rate-limiting.md`
CHILD1_DESC_EOF
)
CHILD1_JSON=$(lsdlc-linear create-issue \
  --team "$TEAM" \
  --title "Rate limiter middleware" \
  --description "$CHILD1_DESC" \
  --priority 2 \
  --parent "$PARENT_ID" \
  --labels "backend")
CHILD1_ID=$(printf '%s' "$CHILD1_JSON" | node -e 'const j=JSON.parse(require("fs").readFileSync(0,"utf8")); process.stdout.write(j.issue.identifier)')
echo "Created child 1: $CHILD1_ID"

CHILD2_DESC=$(cat <<'CHILD2_DESC_EOF'
## Context
Applies the middleware from the foundation ticket to the endpoints most at risk of brute-force abuse.

## Requirements
- Wire the rate limiter into `/auth/login`, `/auth/register`, `/auth/password-reset`
- Use stricter limits than the default (per the spec's Technical Approach)

## Acceptance criteria
- [ ] Login, register, and password reset return 429 after the configured threshold
- [ ] Limits are tuned per endpoint, not inherited from the global default
- [ ] Integration test hits each endpoint repeatedly and asserts the 429

## Implementation notes
Wiring lives in `src/routes/auth.ts`. Pull the per-endpoint limits from config — don't hardcode.

## Dependencies
- Blocked by: the rate limiter middleware ticket (created above)

## Spec
`specs/rate-limiting.md`
CHILD2_DESC_EOF
)
CHILD2_JSON=$(lsdlc-linear create-issue \
  --team "$TEAM" \
  --title "Apply rate limiting to auth endpoints" \
  --description "$CHILD2_DESC" \
  --priority 2 \
  --parent "$PARENT_ID" \
  --labels "backend,security")
CHILD2_ID=$(printf '%s' "$CHILD2_JSON" | node -e 'const j=JSON.parse(require("fs").readFileSync(0,"utf8")); process.stdout.write(j.issue.identifier)')
echo "Created child 2: $CHILD2_ID"

# 3. Wire blocking relationships from the dependency graph.
#    Pass blockedBy / blocks; lsdlc-linear translates to Linear's blocks relation type internally.
lsdlc-linear add-relation "$CHILD2_ID" blockedBy "$CHILD1_ID"
```

After running, Step 5's summary table can pull every identifier from the `echo` lines above (still in the same bash output).

## Step 5: Summary

Present the created tickets:

```
## Created Tickets

| Ticket | Title | Priority | Status | Dependencies |
|--------|-------|----------|--------|-------------|
| VER-60 | Rate Limiting System (parent) | High | Backlog | — |
| VER-61 | Rate limiter middleware | High | Todo | — |
| VER-62 | Apply rate limiting to auth endpoints | High | Todo | Blocked by VER-61 |
| VER-63 | Rate limit response headers | Medium | Todo | Blocked by VER-61 |
| VER-64 | Rate limiting dashboard | Low | Backlog | Blocked by VER-61, VER-62 |

**Spec file:** `specs/rate-limiting.md`
**Start working:** Run `/next` to pick a ticket, or `/implement VER-61` to start with the foundation.
```

## Step 6: Wrap Up

```bash
lsdlc-timeline-log '{"skill":"create-tickets","event":"completed","branch":"'"$_BRANCH"'","outcome":"DONE","tickets_created":4,"parent":"VER-60","session":"'"$_SESSION_ID"'"}' 2>/dev/null
```

```
STATUS: DONE
SUMMARY: Created 4 Linear tickets (VER-60 through VER-64) from specs/rate-limiting.md
```

## Important Rules

1. **Always confirm before creating.** Never create tickets without user approval of the breakdown.
2. **Set dependencies accurately.** Wrong dependencies cause confusion when `/next` recommends tickets.
3. **Every description follows `templates/issue-template.md`.** Parent issues: Problem / Goal / Scope / Out of scope / Spec. Sub-issues: Context / Requirements / Acceptance criteria / Implementation notes / Dependencies / Spec. A sub-issue without a concrete `Acceptance criteria` checklist is broken — `/implement` reads that checklist back when planning and verifying, and `/next` uses it to judge readiness.
4. **Link back to the spec.** Every ticket's `Spec` section references the spec file path.
