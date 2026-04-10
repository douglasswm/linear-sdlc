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
_PROJ="${LSDLC_STATE_DIR:-$HOME/.linear-sdlc}/projects/${_SLUG}"
mkdir -p "$_PROJ/checkpoints"

echo "BRANCH: $_BRANCH"
echo "PROJECT: $_SLUG"

# ─── Wiki resolution ───────────────────────────────────────────
# Single-shot status via `lsdlc-wiki info`. Outputs two lines:
#   PATH=<absolute wiki dir, or empty>
#   LINE=<"WIKI: ..." display line, or empty>
# One subprocess (node) instead of the ~10 we used to spawn
# (find/grep/tail/sed/lsdlc-config). The JSON config is read in-process
# and cached inside lsdlc-wiki, so wiki_linear_sync doesn't need its
# own lsdlc-config call.
_WIKI_INFO=$(lsdlc-wiki info 2>/dev/null || true)
_WIKI=$(printf '%s\n' "$_WIKI_INFO" | sed -n 's/^PATH=//p')
_WIKI_LINE=$(printf '%s\n' "$_WIKI_INFO" | sed -n 's/^LINE=//p')
export _WIKI
[ -n "$_WIKI_LINE" ] && echo "$_WIKI_LINE"
unset _WIKI_INFO _WIKI_LINE

# ─── One-time upgrade notice ───────────────────────────────────
# `./setup` drops this marker when it flips an existing install to
# wiki_scope=repo. Show the notice once, then delete the marker.
_WIKI_UPGRADE_MARKER="${LSDLC_STATE_DIR:-$HOME/.linear-sdlc}/.wiki-upgrade-pending"
if [ -f "$_WIKI_UPGRADE_MARKER" ]; then
  cat <<'EOF'
NOTICE: linear-sdlc wiki mode changed to 'repo' (was implicit 'private').
        Your wiki now belongs in <repo>/.linear-sdlc/wiki/ (shared via git).
        Legacy home-dir wiki at ~/.linear-sdlc/projects/<slug>/wiki is still intact.
        Run /wiki init to scaffold, /wiki migrate to import legacy content,
        or `lsdlc-config set wiki_scope private` to revert.
EOF
  rm -f "$_WIKI_UPGRADE_MARKER"
fi
unset _WIKI_UPGRADE_MARKER

# ─── Session tracking ──────────────────────────────────────────
_SESSION_ID="$$-$(date +%s)"
lsdlc-timeline-log "{\"skill\":\"$SKILL_NAME\",\"event\":\"started\",\"branch\":\"$_BRANCH\",\"session\":\"$_SESSION_ID\"}" 2>/dev/null &

# ─── Error capture helper ──────────────────────────────────────
# Skills call this explicitly at known failure points (right before
# reporting STATUS: BLOCKED or STATUS: DONE_WITH_CONCERNS) to record
# what went wrong as a learning + a timeline event. The function is
# call-site driven by design — a global `trap ERR` would fire on every
# harmless `grep` no-match and pollute the learnings file.
#
# Usage:
#   _lsdlc_capture_error <step> <key> <insight>
#
#   <step>    — short label for where in the skill it failed
#               (e.g. "step-4b" or "specialist-review")
#   <key>     — stable slug for this failure mode
#               (e.g. "linear-401-from-stale-key"). Same key on a re-run
#               appends another row but lsdlc-learnings-search dedups by
#               key+type at read time, so noise is bounded.
#   <insight> — one sentence: what failed and what fixed it / what to
#               try next time. No stack traces, no secrets, no argv dumps.
#
# Storage: writes to learnings.jsonl (per-project state dir, with
# type:"error") AND lsdlc-timeline-log. Does NOT write to
# .linear-sdlc/wiki/log.md — that file is committed to the repo and
# operational failures don't belong in git history.
_lsdlc_capture_error() {
  local step="${1:-unknown}" key="${2:-unknown}" insight="${3:-}"
  [ -z "$insight" ] && return 0
  local payload
  payload=$(node -e '
    const [skill, step, key, insight] = process.argv.slice(1);
    process.stdout.write(JSON.stringify({
      skill, type: "error", step, key, insight,
      confidence: 5, source: "observed"
    }));
  ' "$SKILL_NAME" "$step" "$key" "$insight" 2>/dev/null)
  [ -n "$payload" ] && lsdlc-learnings-log "$payload" 2>/dev/null || true
  lsdlc-timeline-log "{\"skill\":\"$SKILL_NAME\",\"event\":\"error\",\"step\":\"$step\",\"key\":\"$key\",\"branch\":\"$_BRANCH\",\"session\":\"$_SESSION_ID\"}" 2>/dev/null || true
}

# ─── Update check ──────────────────────────────────────────────
# Runs last so it never delays the security/env path or project detection.
# lsdlc-update-check is silent on the happy path and exits 0 on any failure,
# so the `|| true` is belt-and-braces. When it emits an UPDATE_AVAILABLE /
# JUST_UPGRADED line we also print a directive telling Claude to dispatch
# to the /upgrade skill before continuing — this way individual SKILL.md
# files don't each need their own awareness of the feature.
if command -v lsdlc-update-check >/dev/null 2>&1; then
  _LSDLC_UPD="$(lsdlc-update-check 2>/dev/null || true)"
  if [ -n "$_LSDLC_UPD" ]; then
    printf '%s\n' "$_LSDLC_UPD"
    case "$_LSDLC_UPD" in
      UPDATE_AVAILABLE*)
        printf 'NOTE_TO_CLAUDE: A linear-sdlc update is available. Do NOT just tell the user to run /upgrade — execute the /upgrade skill yourself right now (read $LINEAR_SDLC_ROOT/skills/upgrade/SKILL.md and follow it step-by-step). The skill will present a 4-option AskUserQuestion dialog (Yes / Always / Not now / Never) so the user picks the action; your job is to drive the flow, not to defer it. After the upgrade dialog resolves, resume the current skill.\n'
        ;;
    esac
  fi
  unset _LSDLC_UPD
fi
