# Shared Preamble

Every skill runs a two-step preamble in its very first bash block:

1. An inline **bootstrap** (~12 lines) that resolves `$LINEAR_SDLC_ROOT` from the skill's own symlink target.
2. A `.`-source of **`references/preamble.sh`**, which holds the parts that every skill needs identically — safe env-file loading, git branch + project slug detection, state dir creation, and session tracking via `lsdlc-timeline-log`.

After sourcing, each `SKILL.md` prints its own context lines (learnings, wiki, last session, checkpoints, last health score — whichever matter to that skill) and closes with `echo "---"`.

## Frontmatter

Each `SKILL.md` must include `model` and `effort` fields in its YAML frontmatter to control which Claude model runs the skill and how much reasoning depth to apply.

| Field | Values | Description |
|-------|--------|-------------|
| `model` | `opus`, `sonnet`, `haiku`, `opus[1m]`, `sonnet[1m]` | Which Claude model runs this skill |
| `effort` | `low`, `medium`, `high`, `max` (Opus only) | Reasoning depth — higher = slower but more thorough |

Current assignments:
- **Opus + medium**: `/brainstorm` — feature planning, cross-domain synthesis
- **Sonnet + medium**: `/implement`, `/create-tickets`, `/debug`, `/health` — full lifecycle, structured judgment, diagnostic discipline
- **Sonnet + low**: `/checkpoint` — mechanical state dump/restore
- **Haiku + low**: `/next` — fast list, rank, present

## The bootstrap block

Copy this block verbatim into each new `SKILL.md`. Change only the `SKILL_NAME=` value to match the skill's directory name.

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
SKILL_NAME=brainstorm . "$LINEAR_SDLC_ROOT/references/preamble.sh"
```

The bootstrap probes both the short (`brainstorm`) and prefixed (`linear-sdlc-brainstorm`) symlink locations to handle both install modes (`./setup` and `./setup --prefix`), then walks up two levels from the resolved symlink to find the repo root. Falls back to `lsdlc-config get source_dir` if no symlink is found (first install, custom layout, etc.).

## What `preamble.sh` does

See `references/preamble.sh` for the authoritative version. In short:

1. **Load `LINEAR_API_KEY` safely.** Parses `$LSDLC_STATE_DIR/env` line-by-line (never `.`-sources it), after checking that the file is mode `?00` and owned by the current user. Mirrors the pure-JS parser in `bin/lsdlc-linear`. Not sourcing is the whole point — the env file lives in a user-writable directory and a compromised process could otherwise inject code through it.
2. **Detect the project.** Sets `_BRANCH`, `_SLUG`, `_PROJ` and `mkdir -p`s the state directory.
3. **Start session tracking.** Sets `_SESSION_ID` and fires off `lsdlc-timeline-log` with a `started` event.

The skill body adds its own display lines after sourcing, and each skill controls its own `echo "---"` separator.

## When to edit `preamble.sh`

- Adding something every skill needs identically (new env loader, new detection step) → edit `preamble.sh`.
- Adding something that only one or two skills care about (checkpoint counts, health history, wiki pages) → inline it in the affected `SKILL.md` after the source.

Changes to `preamble.sh` take effect on the next skill run — no reinstall, no build step.
