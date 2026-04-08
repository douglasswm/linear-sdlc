---
name: upgrade
description: |
  Upgrade linear-sdlc to the latest release. Triggered automatically when the
  shared preamble detects a newer version (UPDATE_AVAILABLE line), or run
  manually with `/upgrade`. Handles the Yes / Always / Not now / Never dialog,
  performs the git upgrade, and prints what's new.
model: sonnet
effort: medium
allowed-tools:
  - Bash
  - Read
  - AskUserQuestion
---

# /upgrade — Upgrade linear-sdlc

## Preamble

Run this first:

```bash
# Bootstrap: resolve LINEAR_SDLC_ROOT from this skill's symlink, then source
# the shared preamble (safe env loader + project detection + session tracking).
if [ -z "${LINEAR_SDLC_ROOT:-}" ]; then
  for _c in "$HOME/.claude/skills/upgrade/SKILL.md" \
            "$HOME/.claude/skills/linear-sdlc-upgrade/SKILL.md"; do
    if [ -L "$_c" ]; then
      LINEAR_SDLC_ROOT="$(cd "$(dirname "$(readlink "$_c")")/../.." && pwd)"
      break
    fi
  done
  [ -z "${LINEAR_SDLC_ROOT:-}" ] && LINEAR_SDLC_ROOT="$(lsdlc-config get source_dir 2>/dev/null || true)"
  export LINEAR_SDLC_ROOT
fi
SKILL_NAME=upgrade . "$LINEAR_SDLC_ROOT/references/preamble.sh"

# Current versions (local + what the check says is available)
_LOCAL_VER=$(head -n1 "$LINEAR_SDLC_ROOT/VERSION" 2>/dev/null | tr -d '[:space:]')
echo "LOCAL_VERSION: ${_LOCAL_VER:-unknown}"

# Force a fresh check so the dialog never lies about what's available.
_UPD=$(lsdlc-update-check --force 2>/dev/null || true)
if [ -n "$_UPD" ]; then
  echo "CHECK_RESULT: $_UPD"
fi

_AUTO=$(lsdlc-config get auto_upgrade 2>/dev/null || true)
echo "AUTO_UPGRADE: ${_AUTO:-false}"

echo "---"
```

## Step 1: Determine What's Available

Parse the `CHECK_RESULT` line from the preamble. Possible shapes:

- `CHECK_RESULT: UPDATE_AVAILABLE <old> <new>` — upgrade is possible, proceed to Step 2.
- `CHECK_RESULT: JUST_UPGRADED <old> <new>` — user already upgraded; **skip to Step 6** (show what's new + DONE).
- No `CHECK_RESULT` line — either up-to-date, opted out, or offline. Report `STATUS: DONE` with a one-line summary ("already up to date" / "network check failed — try again later") and stop.

Extract `<old>` and `<new>` from the `UPDATE_AVAILABLE` line — you'll pass them to the dialog.

## Step 2: Auto-Upgrade Short-Circuit

If the preamble shows `AUTO_UPGRADE: true`, **skip the dialog entirely** and jump straight to Step 4 (Perform Upgrade). The user already told us "always keep me up to date", so nagging them again would be wrong.

Otherwise continue to Step 3.

## Step 3: Ask the User

Use `AskUserQuestion` to present four options. Follow the template in `references/ask-user-format.md`.

```
**Re-ground:** A newer linear-sdlc release is available (v<old> → v<new>).

**Context:** The shared preamble detected the new version when you ran the
current skill. Upgrading now takes ~10 seconds and runs `./setup` to pick up
any schema or wiring changes. Your state (learnings, checkpoints, wiki,
Linear config) lives in `~/.linear-sdlc/` and is not touched.

**Options:**
1. **Yes, upgrade now** — pull the new version, run `./setup`, resume the current task (recommended)
2. **Always keep me up to date** — set `auto_upgrade: true` and upgrade from now on without asking
3. **Not now** — snooze this notification (24h the first time, then 48h, then 7d)
4. **Never ask again** — disable all update checks (`update_check: false`)

**Recommendation:** Upgrade now. Release notes are short and the operation is reversible via `git reflog` in `$LINEAR_SDLC_ROOT`.
```

Handle the response:

### Option 1 — Yes, upgrade now
Continue to Step 4.

### Option 2 — Always keep me up to date
```bash
lsdlc-config set auto_upgrade true
echo "Auto-upgrade enabled. Future releases will install silently."
```
Continue to Step 4.

### Option 3 — Not now (escalating snooze)
```bash
NEW_VER="<new>"  # from CHECK_RESULT
STATE_DIR="${LSDLC_STATE_DIR:-$HOME/.linear-sdlc}"
SNOOZE_FILE="$STATE_DIR/update-snoozed"

# Read existing snooze level for this exact version, default 0.
OLD_LEVEL=0
if [ -f "$SNOOZE_FILE" ]; then
  read _sv _sl _st < "$SNOOZE_FILE" 2>/dev/null || true
  [ "$_sv" = "$NEW_VER" ] && OLD_LEVEL=${_sl:-0}
fi
NEW_LEVEL=$((OLD_LEVEL + 1))
[ $NEW_LEVEL -gt 3 ] && NEW_LEVEL=3

mkdir -p "$STATE_DIR"
printf '%s %s %s\n' "$NEW_VER" "$NEW_LEVEL" "$(date +%s)" > "$SNOOZE_FILE"

case $NEW_LEVEL in
  1) WINDOW="24 hours" ;;
  2) WINDOW="48 hours" ;;
  *) WINDOW="7 days" ;;
esac
echo "Snoozed until the next notification (level $NEW_LEVEL — $WINDOW)."
```
Then report `STATUS: DONE` and return control to the previous skill (or stop if `/upgrade` was invoked directly). **Do not proceed to Step 4.**

### Option 4 — Never ask again
```bash
lsdlc-config set update_check false
echo "Update checks disabled. Re-enable with: lsdlc-config unset update_check"
```
Then report `STATUS: DONE` and return control. **Do not proceed to Step 4.**

## Step 4: Perform Upgrade

The only supported install shape is a git checkout. Verify that first:

```bash
cd "$LINEAR_SDLC_ROOT"
if [ ! -d ".git" ]; then
  echo "ERROR: $LINEAR_SDLC_ROOT is not a git checkout — cannot auto-upgrade."
  echo "Re-install manually:"
  echo "  rm -rf $LINEAR_SDLC_ROOT"
  echo "  git clone git@github.com:douglasswm/linear-sdlc.git $LINEAR_SDLC_ROOT"
  echo "  cd $LINEAR_SDLC_ROOT && ./setup"
  exit 1
fi
```

Stash any in-progress changes to the checkout (rare, but cheap insurance), fetch, and fast-forward. If the working tree has local edits to the source we should refuse rather than silently discard them:

```bash
cd "$LINEAR_SDLC_ROOT"

# Refuse if there are uncommitted changes we'd clobber.
if ! git diff --quiet || ! git diff --cached --quiet; then
  echo "ERROR: $LINEAR_SDLC_ROOT has uncommitted changes."
  echo "Commit, stash, or discard them before upgrading:"
  git status --short
  exit 1
fi

# Fetch + fast-forward.
git fetch origin
OLD_HEAD=$(git rev-parse HEAD)
git reset --hard origin/main
NEW_HEAD=$(git rev-parse HEAD)

if [ "$OLD_HEAD" = "$NEW_HEAD" ]; then
  echo "Already at origin/main — nothing to do."
else
  echo "Upgraded: $OLD_HEAD → $NEW_HEAD"
fi
```

Run `./setup` in non-interactive mode so it doesn't prompt for API key / team id again:

```bash
cd "$LINEAR_SDLC_ROOT"
./setup --skip-api-key --skip-mcp-prompt -q
```

## Step 5: Post-Upgrade Bookkeeping

```bash
STATE_DIR="${LSDLC_STATE_DIR:-$HOME/.linear-sdlc}"
NEW_VER=$(head -n1 "$LINEAR_SDLC_ROOT/VERSION" 2>/dev/null | tr -d '[:space:]')
OLD_VER="<old from CHECK_RESULT>"   # substitute the real value

# Marker so the NEXT skill invocation prints JUST_UPGRADED once.
mkdir -p "$STATE_DIR"
printf '%s %s\n' "$OLD_VER" "$NEW_VER" > "$STATE_DIR/just-upgraded-from"

# Invalidate the update check cache and any snooze state.
rm -f "$STATE_DIR/last-update-check" "$STATE_DIR/update-snoozed"
```

## Step 6: Show What's New

Print the CHANGELOG section for `<new>` so the user knows what they just got. The CHANGELOG headers look like `## v2.1.0 — 2026-04-09 — <tagline>`. Extract the block between this version's header and the next one:

```bash
awk -v v="$NEW_VER" '
  $0 ~ "^## v" v " " { printing = 1; print; next }
  printing && /^## v/ { exit }
  printing { print }
' "$LINEAR_SDLC_ROOT/CHANGELOG.md"
```

If the awk produces no output (the CHANGELOG header format drifted), fall back to printing the first 40 lines of CHANGELOG.md.

## Step 7: Wrap Up

```bash
lsdlc-timeline-log '{"skill":"upgrade","event":"completed","branch":"'"$_BRANCH"'","outcome":"DONE","session":"'"$_SESSION_ID"'"}' 2>/dev/null
```

Report status using the protocol in `references/completion-status.md`:

```
STATUS: DONE
SUMMARY: Upgraded linear-sdlc v<old> → v<new>
```

If `/upgrade` was dispatched automatically by the shared preamble (the caller was mid-task in another skill), tell Claude to **resume the previous skill now** rather than waiting for the user.

## Important Rules

1. **Never clobber uncommitted source changes.** If `git status` is dirty, refuse and tell the user to commit/stash/discard.
2. **Honor auto_upgrade silently.** If the config says "always upgrade", do not prompt — upgrading without a dialog is the whole point of that setting.
3. **Snooze is per-version.** Level escalates only when the user snoozes the same version multiple times. A new remote release resets the snooze back to level 1 so the user hears about real news.
4. **Never persist secrets.** This skill only reads/writes `auto_upgrade` and `update_check` config keys. The Linear API key and team ID are untouched.
5. **Always clear the cache and snooze after upgrading.** Otherwise the next preamble run will either re-notify for the old version or stay silent when it shouldn't.
