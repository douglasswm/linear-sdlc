# Shared Preamble

Every skill runs this bash block first. It detects the project context, loads learnings, recovers session state, and starts timeline tracking.

Copy this block into each SKILL.md after the YAML frontmatter.

## Frontmatter

Each SKILL.md must include `model` and `effort` fields in its YAML frontmatter to control which Claude model runs the skill and how much reasoning depth to apply.

| Field | Values | Description |
|-------|--------|-------------|
| `model` | `opus`, `sonnet`, `haiku`, `opus[1m]`, `sonnet[1m]` | Which Claude model runs this skill |
| `effort` | `low`, `medium`, `high`, `max` (Opus only) | Reasoning depth — higher = slower but more thorough |

Current assignments:
- **Opus + high**: `/brainstorm`, `/implement` — deep reasoning, creative/complex work
- **Sonnet + medium**: root skill, `/create-tickets`, `/health` — structured, mechanical tasks
- **Sonnet + low**: `/checkpoint` — simple state gathering
- **Haiku + low**: `/next` — fast query and present

```bash
# Detect project
_BRANCH=$(git branch --show-current 2>/dev/null || echo "unknown")
_SLUG=$(~/.claude/skills/linear-sdlc/bin/lsdlc-slug 2>/dev/null | grep '^SLUG=' | cut -d= -f2 || basename "$(git rev-parse --show-toplevel 2>/dev/null || pwd)")
_PROJ="${HOME}/.linear-sdlc/projects/${_SLUG}"
mkdir -p "$_PROJ/checkpoints" "$_PROJ/wiki"

echo "BRANCH: $_BRANCH"
echo "PROJECT: $_SLUG"

# Load learnings
_LEARN_FILE="$_PROJ/learnings.jsonl"
if [ -f "$_LEARN_FILE" ]; then
  _LEARN_COUNT=$(wc -l < "$_LEARN_FILE" | tr -d ' ')
  echo "LEARNINGS: $_LEARN_COUNT entries"
  [ "$_LEARN_COUNT" -gt 0 ] && ~/.claude/skills/linear-sdlc/bin/lsdlc-learnings-search --limit 3 2>/dev/null || true
else
  echo "LEARNINGS: 0"
fi

# Wiki status
_WIKI_PAGES=$(find "$_PROJ/wiki" -name "*.md" ! -name "index.md" ! -name "log.md" 2>/dev/null | wc -l | tr -d ' ')
echo "WIKI: $_WIKI_PAGES pages"

# Context recovery
if [ -f "$_PROJ/timeline.jsonl" ]; then
  _LAST=$(grep "\"branch\":\"${_BRANCH}\"" "$_PROJ/timeline.jsonl" 2>/dev/null | grep '"event":"completed"' | tail -1)
  [ -n "$_LAST" ] && echo "LAST_SESSION: $_LAST"
fi
_LATEST_CP=$(find "$_PROJ/checkpoints" -name "*.md" -type f 2>/dev/null | xargs ls -1t 2>/dev/null | head -1)
[ -n "$_LATEST_CP" ] && echo "LATEST_CHECKPOINT: $_LATEST_CP"

# Session tracking
_SESSION_ID="$$-$(date +%s)"
~/.claude/skills/linear-sdlc/bin/lsdlc-timeline-log '{"skill":"SKILL_NAME","event":"started","branch":"'"$_BRANCH"'","session":"'"$_SESSION_ID"'"}' 2>/dev/null &

echo "---"
```

Replace `SKILL_NAME` with the actual skill name (e.g., `implement`, `next`, `brainstorm`).
