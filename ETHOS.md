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

## Simplicity

No build steps. No compilation. No complex toolchains. Bash scripts and markdown files. If a feature requires more infrastructure than `node -e`, question whether it's needed in V1.
