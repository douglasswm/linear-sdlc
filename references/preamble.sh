# linear-sdlc shared preamble — sourced by every skill.
#
# Contract (caller must satisfy BEFORE sourcing):
#   - SKILL_NAME    — name of the skill ("brainstorm", "implement", ...)
#   - LINEAR_SDLC_ROOT — absolute path to the linear-sdlc checkout
#                        (each SKILL.md's bootstrap resolves this from its
#                         own symlink before sourcing this file)
#
# What this file does, in order:
#   1. Loads LINEAR_API_KEY from ~/.linear-sdlc/env — safely, by parsing the
#      file (never `. file`) and refusing to read if perms/ownership look bad.
#   2. Detects the current git branch and project slug, creates the state dir.
#   3. Starts session tracking via lsdlc-timeline-log.
#
# The caller (each SKILL.md) handles its own info-display lines (learnings,
# wiki, checkpoints, last-health, etc.) AFTER sourcing, and prints the final
# `echo "---"` separator itself. That per-skill customization is intentional;
# the goal here is to dedupe the security-critical and context-critical parts.

: "${SKILL_NAME:?preamble.sh: caller must set SKILL_NAME}"
: "${LINEAR_SDLC_ROOT:?preamble.sh: caller must set LINEAR_SDLC_ROOT}"

# ─── Safe LINEAR_API_KEY loader ────────────────────────────────
# Pure-shell parser. Matches bin/lsdlc-linear's Node-side parser
# (see bin/lsdlc-linear:44-60) so both code paths agree on what
# counts as a well-formed env file.
#
# Why not `. file`? The env file lives in ~/.linear-sdlc/, which is
# user-writable. Any process running as the user could append arbitrary
# shell to it; dot-sourcing would execute that on next skill run. Parsing
# the single key line instead closes that RCE surface.
_lsdlc_load_env() {
  local env_file="${LSDLC_STATE_DIR:-$HOME/.linear-sdlc}/env"
  [ -n "${LINEAR_API_KEY:-}" ] && return 0
  [ -f "$env_file" ] || return 0

  # Refuse to read if group/other-writable or not owned by us.
  # BSD stat on macOS, GNU stat on Linux — try both.
  local mode owner
  mode=$(stat -f '%Lp' "$env_file" 2>/dev/null || stat -c '%a' "$env_file" 2>/dev/null || echo "")
  owner=$(stat -f '%u' "$env_file" 2>/dev/null || stat -c '%u' "$env_file" 2>/dev/null || echo "")

  # Normalize mode to 3 digits (600 not just 600, but also 0600 → 600).
  case ${#mode} in
    4) mode=${mode#?} ;;
  esac

  if [ -n "$mode" ]; then
    case "$mode" in
      ?00) : ;;  # 600, 400, 000 — ok
      *)
        echo "WARN: $env_file has permissive mode $mode (expected 600) — refusing to read" >&2
        return 0
        ;;
    esac
  fi
  if [ -n "$owner" ] && [ "$owner" != "$(id -u)" ]; then
    echo "WARN: $env_file is not owned by you — refusing to read" >&2
    return 0
  fi

  # Parse only the key line. Never eval.
  local line val
  line=$(grep -E '^[[:space:]]*(export[[:space:]]+)?LINEAR_API_KEY=' "$env_file" 2>/dev/null | head -1)
  [ -n "$line" ] || return 0
  val=${line#*LINEAR_API_KEY=}
  # Strip a single pair of surrounding quotes (single or double).
  case "$val" in
    \'*\') val=${val#\'}; val=${val%\'} ;;
    \"*\") val=${val#\"}; val=${val%\"} ;;
  esac
  # Charset check mirrors bin/lsdlc-linear:57.
  case "$val" in
    '') return 0 ;;
    *[!A-Za-z0-9_-]*)
      echo "WARN: LINEAR_API_KEY in $env_file has invalid characters — refusing to load" >&2
      return 0
      ;;
    *)
      export LINEAR_API_KEY="$val"
      ;;
  esac
}
_lsdlc_load_env
unset -f _lsdlc_load_env

# ─── Project detection ─────────────────────────────────────────
_BRANCH=$(git branch --show-current 2>/dev/null || echo "unknown")
_SLUG=$(lsdlc-slug 2>/dev/null | grep '^SLUG=' | cut -d= -f2)
if [ -z "$_SLUG" ]; then
  _SLUG=$(basename "$(git rev-parse --show-toplevel 2>/dev/null || pwd)")
fi
_PROJ="${HOME}/.linear-sdlc/projects/${_SLUG}"
mkdir -p "$_PROJ/checkpoints" "$_PROJ/wiki"

echo "BRANCH: $_BRANCH"
echo "PROJECT: $_SLUG"

# ─── Session tracking ──────────────────────────────────────────
_SESSION_ID="$$-$(date +%s)"
lsdlc-timeline-log "{\"skill\":\"$SKILL_NAME\",\"event\":\"started\",\"branch\":\"$_BRANCH\",\"session\":\"$_SESSION_ID\"}" 2>/dev/null &
