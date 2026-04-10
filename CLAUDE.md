# linear-sdlc — notes for Claude

This repo is a Claude Code **skills pack** that implements a Linear-driven SDLC workflow. Read `README.md` for the user-facing description. Repo internals (layout, setup wiring, state dir, autoupdate, hacking recipes, regression greps, testing) live in `docs/hacking.md` — this file is intentionally short to keep context light. **Read `docs/hacking.md` before making any non-trivial change to setup, the preamble, the wiki plumbing, autoupdate, or `bin/lsdlc-linear`.**

## What you must not forget

- **Not a plugin.** No `.claude-plugin/`, no `plugin.json`, no embedded MCP server. v1 was a plugin; v2 reverted to a gstack-style skills pack. Don't write `${CLAUDE_PLUGIN_ROOT}` — that variable no longer exists. Reference repo files via `$LINEAR_SDLC_ROOT/...` (the shared preamble exports it).
- **Skills don't depend on the official Linear MCP.** Every Linear call goes through `bin/lsdlc-linear` (a Node helper that wraps the GraphQL API). The official MCP is mentioned in setup output as a nice-to-have for ad-hoc queries, but skills must not branch on it.
- **Bin scripts are invoked as bare commands.** Setup symlinks them into `~/.local/bin`. Write `lsdlc-linear get-issue VER-42`, not a path.

## Critical security invariants

- **`LINEAR_API_KEY` never appears on argv, in shell strings, or in error output.** `bin/lsdlc-linear` reads it from `process.env` (with a fallback to parsing `~/.linear-sdlc/env` in pure JS). A key containing `$`, `'`, or backticks would break shell quoting in unsafe ways. If you add a new code path that needs the key, use `process.env` only — never interpolate it into a `node -e` string literal or any other shell context.
- **The shared preamble never `.`-sources `~/.linear-sdlc/env`.** That file is user-writable, so dot-sourcing would be an RCE surface. `references/preamble.sh` parses the single key line in pure shell and refuses to read if perms are >600 or ownership is wrong. Don't replace it with `source` / `.`.
- **Only the shared preamble and `/upgrade` may call `lsdlc-update-check`.** If any other skill body calls it directly, fold the call back into `references/preamble.sh`.

## Conventions

- **Editing the shared preamble:** `references/preamble.sh` is sourced live by every skill — your changes take effect on the next skill run with no reinstall. The ~12-line bootstrap block in each `SKILL.md` only changes if the symlink layout changes.
- **Adding a skill:** drop `skills/<new>/SKILL.md` with standard frontmatter, then re-run `./setup` — it gets symlinked automatically.
- **Model/effort changes are three-place edits.** Updating a skill's `model:` or `effort:` means updating skill frontmatter, the README "Skills" table, and ETHOS.md "Right Model for the Job" in lockstep. Miss one and the docs lie. Defaults are tuned for typical workloads (brainstorm = opus/medium for synthesis; implement = sonnet/medium because heavy reasoning happens in specialist sub-agents).
- **Team filtering in `lsdlc-linear`:** the `linear_team_id` config field accepts either a short key (`VER`) or a UUID. Use the existing `teamFilter()` / `teamMatches()` helpers — don't hardcode `key`.
- **Commits:** no `Co-Authored-By: Claude` trailers, no "Generated with Claude Code" lines (also a global rule in `~/.claude/CLAUDE.md`).
- **Skill invocation in docs:** use the bare form (`/brainstorm`). If you also need to mention the prefixed form, write `/linear-sdlc-brainstorm` (dash, not colon — the colon was a v1 plugin convention).

For repo layout, setup wiring, state-dir contents, three-layer wiki model, autoupdate + team mode internals, regression greps, and testing recipes, see `docs/hacking.md`.
