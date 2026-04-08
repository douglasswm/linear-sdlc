# linear-sdlc — notes for Claude

This repo is a set of Claude Code skills that implement a Linear-driven SDLC workflow. Read `README.md` for the user-facing description; this file is for agents working on the repo itself.

## Layout

- `SKILL.md` (root) — session-start skill loaded when users say "linear-sdlc". Runs a preamble and dispatches to sub-skills.
- `<skill>/SKILL.md` — one per skill: `brainstorm`, `create-tickets`, `next`, `implement`, `checkpoint`, `health`. Each has YAML frontmatter (`name`, `description`, `model`, `effort`, `allowed-tools`) followed by the prompt body.
- `implement/specialists/*.md` — checklists consumed by parallel sub-agents during `/implement`'s self-review phase (testing, security, performance, code-quality).
- `bin/lsdlc-*` — shell helpers for state management. `lsdlc-slug` derives the project slug from the git remote, `lsdlc-config` reads/writes `~/.linear-sdlc/config.json`, `lsdlc-learnings-*` and `lsdlc-timeline-log` append to JSONL state files, `lsdlc-wiki-*` synthesize learnings into markdown pages.
- `templates/spec-template.md` — the spec file `/brainstorm` writes and `/create-tickets` reads.
- `references/` — shared prompt fragments (preamble, ask-user-format, completion-status) included by skill bodies.
- `ETHOS.md` — design principles. **Keep in sync with reality** — when changing model defaults or workflow behavior, update ETHOS too or it becomes a lie.
- `setup` — install/update script. See "Installation and the symlink" below.

## Installation and the symlink

`./setup` symlinks `~/.claude/skills/linear-sdlc` → this repo, plus one symlink per sub-skill directory that has a `SKILL.md`. So edits to files in this repo take effect immediately in any Claude Code session — no reinstall. The repo path shown in `git rev-parse --show-toplevel` and the skill path at `~/.claude/skills/linear-sdlc/` point to the same files.

Linear API key is stored in `~/.claude/settings.json` under `mcpServers.linear.env.LINEAR_API_KEY`. The setup script detects an existing key and offers to keep or replace it; set `LINEAR_API_KEY=...` in the env to bypass the prompt for CI / non-interactive use.

## State directory

Persistent state lives outside the repo at `~/.linear-sdlc/`:

```
~/.linear-sdlc/
├── config.json                       # linear_team_id, user prefs
└── projects/<slug>/
    ├── learnings.jsonl               # append-only operational notes
    ├── timeline.jsonl                # skill execution log
    ├── <branch>-reviews.jsonl        # specialist findings per branch
    ├── health-history.jsonl          # /health score trend
    ├── wiki/                         # synthesized knowledge
    └── checkpoints/                  # /checkpoint session state
```

Slug is derived from the git remote. Each repo gets isolated state.

## Testing changes without breaking the real world

- **Setup script:** use a throwaway `HOME` for smoke tests. See the test pattern used earlier in this repo's history — `TMP=$(mktemp -d); HOME="$TMP" LINEAR_API_KEY=test_key ./setup` runs the full install flow against a fake home dir and lets you inspect the result without touching the user's real `~/.claude/settings.json`.
- **Skill frontmatter:** after changing `model:` or `effort:`, verify the YAML parses by running `head -15 <skill>/SKILL.md` and visually checking. There is no build step.
- **Bin scripts:** most read/write `~/.linear-sdlc/`. Use `LSDLC_STATE_DIR=/tmp/test-state <script>` when one supports the env override (check the script source — `lsdlc-config` does).
- **Portability:** the `setup` shebang is `#!/bin/bash`. macOS ships bash 3.2, so avoid bash 4+ features (associative arrays, `${var^^}`, `readarray`). Negative-offset substring `${var: -4}` is fine (verified against 3.2.57).

## Conventions

- **Model and effort defaults:** tuned for typical workloads, not worst case. `brainstorm` is `opus/medium` (synthesis for feature planning), `implement` is `sonnet/medium` (most tickets are small, heavy reasoning happens in specialist sub-agents). See `README.md` "Why different models?" for per-skill rationale. If you change these, update the README table *and* the ETHOS.md "Right Model for the Job" section or they drift.
- **Model changes = three places:** skill frontmatter, README table, ETHOS.md. Miss any and the docs lie.
- **No bare `./setup` in docs aimed at Claude Code.** It blocks on interactive `read` — always pair it with `LINEAR_API_KEY="..."` when Claude will run it. The README's "Option 1: one-liner" already handles this; don't regress it.
- **Never interpolate secrets into `node -e` string literals.** The Linear API key is passed via `process.env` for a reason — a key containing `$`, `'`, or backticks would break JSON or execute JS. See `setup` for the pattern.
- **Commits:** no `Co-Authored-By: Claude` trailers, no "Generated with Claude Code" lines (this is also a global preference in `~/.claude/CLAUDE.md`).

## Security posture

`~/.claude/settings.json` currently ships with `-rw-r--r--` (644) permissions from the user's existing Claude Code install. That's world-readable on the local machine — acceptable for a personal dev laptop, not great. Open improvement: have `setup` `chmod 600 "$SETTINGS"` after writing. Not yet done.
