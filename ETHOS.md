# linear-sdlc Design Principles

## Ticket-Driven Development

Every code change traces back to a Linear ticket. No orphan branches, no undocumented work. The ticket is the source of truth for why a change exists.

## Specialist Reviews Before Merge

Code doesn't ship without automated specialist review. Testing, security, performance, and code quality specialists examine every diff. Critical findings block the PR. This catches what humans miss under deadline pressure.

## Knowledge Accumulates Across Sessions and Across Teammates

Every session leaves the project smarter. Raw observations accumulate privately per user in `learnings.jsonl`. Synthesized knowledge accumulates **across the team** in the project wiki at `<repo>/.linear-sdlc/wiki/`, committed via git so teammates share it. The wiki follows the llm_wiki three-layer pattern: raw sources (code, tickets, learnings, external files) → LLM-authored wiki pages → schema (`CLAUDE.md`) that teaches Claude how to maintain them. `/implement` and `/debug` auto-ingest on completion; explorations filed back via `/wiki query` compound the knowledge base over time. Future sessions — and future teammates — start with context, not from scratch.

## Synthesis Is Curated, Not Automatic

Private learnings never auto-flow into the shared wiki. The LLM synthesizes entity/concept/ticket/incident pages primarily from code and ticket context, and every draft runs through a hard `lsdlc-wiki secret-scan` gate before writing. Wiki edits are left in the working tree — never auto-committed — so every synthesis has a `git diff` review window before reaching origin. If a project is too sensitive to synthesize in a shared location at all, `wiki_scope=private` is a first-class escape hatch that keeps the wiki in the user's home directory.

## User Sovereignty

The human decides. Skills recommend, present options, and provide evidence — but never act unilaterally on decisions that matter. Every destructive action requires confirmation. Every recommendation explains its reasoning.

## Completeness Over Speed

Do the whole thing. Don't skip the review step because it's "just a small change." Don't skip logging because "we'll remember." The cost of incomplete work compounds; the cost of thorough work is paid once.

## Right Model for the Job

Not every task needs the most powerful model. Skills declare which Claude model and effort level they need. Foundational synthesis — day-zero project chartering (`/kickoff`) and feature brainstorming (`/brainstorm`) — gets Opus at medium effort; both are read by every later skill, so getting them wrong ripples for the life of the project, but the human drives pacing so max effort isn't justified. Full-lifecycle implementation gets Sonnet at medium effort — most tickets are small and the heavy reasoning happens in specialist sub-agents during self-review. Debugging gets Sonnet at medium effort — diagnostic reasoning needs structure (component-boundary evidence, hypothesis discipline) but not Opus-level creativity. Structured tasks (ticket creation, retrofitting stale ticket descriptions against the template, health checks) get Sonnet at medium effort. Simple lookups (next ticket) get Haiku. Defaults are tuned for typical workloads, not worst case — users escalate manually for genuinely architectural work. This saves cost and latency without sacrificing quality where it matters.

## Verification Before Completion

Claims of "done", "fixed", or "passing" must be grounded in fresh evidence — not in memory of what the conversation said three turns ago. `/implement`, `/checkpoint`, and `/health` run their verification commands at the moment of reporting and cite the literal output. See `references/verification-gate.md` for the pattern.

## Debugging Discipline

`/debug` focuses on phase-1 diagnostic rigor: reproduce, identify component boundaries, instrument, observe, and only then hypothesize the root cause. The goal is to pinpoint the first boundary where data becomes wrong, not to guess from the crash site. The invariant "observe before fixing" is a soft recommendation, not an iron law — User Sovereignty still applies.

## Depend on Official Integrations

When Anthropic or a vendor (e.g., Linear) ships a first-party tool, prefer pointing users at the vendor's standard install mechanism over embedding our own copy. Embedding creates maintenance burden, version skew, and brittle interpolation against whatever Claude Code's config schema looks like this month. linear-sdlc instructs users to install Linear's official HTTP MCP server separately (`claude mcp add --transport http linear https://mcp.linear.app/mcp`) and uses direct GraphQL via `bin/lsdlc-linear` for everything skills actually need. The MCP is a nice-to-have for ad-hoc Linear queries; the skills don't depend on it.

## Simplicity

No build steps. No compilation. No complex toolchains. Bash scripts and markdown files. If a feature requires more infrastructure than `node -e`, question whether it's needed in V1.
