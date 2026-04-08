# linear-sdlc Design Principles

## Ticket-Driven Development

Every code change traces back to a Linear ticket. No orphan branches, no undocumented work. The ticket is the source of truth for why a change exists.

## Specialist Reviews Before Merge

Code doesn't ship without automated specialist review. Testing, security, performance, and code quality specialists examine every diff. Critical findings block the PR. This catches what humans miss under deadline pressure.

## Knowledge Accumulates Across Sessions

Every session leaves the project smarter. Learnings are logged, patterns are recognized, pitfalls are remembered. The wiki synthesizes raw observations into actionable knowledge. Future sessions start with context, not from scratch.

## User Sovereignty

The human decides. Skills recommend, present options, and provide evidence — but never act unilaterally on decisions that matter. Every destructive action requires confirmation. Every recommendation explains its reasoning.

## Completeness Over Speed

Do the whole thing. Don't skip the review step because it's "just a small change." Don't skip logging because "we'll remember." The cost of incomplete work compounds; the cost of thorough work is paid once.

## Right Model for the Job

Not every task needs the most powerful model. Skills declare which Claude model and effort level they need. Creative planning work (brainstorming) gets Opus for cross-domain synthesis, at medium effort since the human drives pacing. Full-lifecycle implementation gets Sonnet at medium effort — most tickets are small and the heavy reasoning happens in specialist sub-agents during self-review. Debugging gets Sonnet at medium effort — diagnostic reasoning needs structure (component-boundary evidence, hypothesis discipline) but not Opus-level creativity. Structured tasks (ticket creation, health checks) get Sonnet at medium effort. Simple lookups (next ticket) get Haiku. Defaults are tuned for typical workloads, not worst case — users escalate manually for genuinely architectural work. This saves cost and latency without sacrificing quality where it matters.

## Verification Before Completion

Claims of "done", "fixed", or "passing" must be grounded in fresh evidence — not in memory of what the conversation said three turns ago. `/linear-sdlc:implement`, `/linear-sdlc:checkpoint`, and `/linear-sdlc:health` run their verification commands at the moment of reporting and cite the literal output. See `references/verification-gate.md` for the pattern.

## Debugging Discipline

`/linear-sdlc:debug` focuses on phase-1 diagnostic rigor: reproduce, identify component boundaries, instrument, observe, and only then hypothesize the root cause. The goal is to pinpoint the first boundary where data becomes wrong, not to guess from the crash site. The invariant "observe before fixing" is a soft recommendation, not an iron law — User Sovereignty still applies.

## Simplicity

No build steps. No compilation. No complex toolchains. Bash scripts and markdown files. If a feature requires more infrastructure than `node -e`, question whether it's needed in V1.
