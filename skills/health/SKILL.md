---
name: health
description: |
  Code quality dashboard. Detects project tools (lint, typecheck, test),
  runs each, computes a weighted composite score 0-10, and tracks trends.
  Use when: "health", "code quality", "run checks", "how healthy".
model: sonnet
effort: medium
allowed-tools:
  - Bash
  - Read
  - Glob
  - AskUserQuestion
---

# /health — Code Quality Dashboard

## Preamble

Run this first:

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
SKILL_NAME=health . "$LINEAR_SDLC_ROOT/references/preamble.sh"

# Previous health score (skill-specific display)
if [ -f "$_PROJ/health-history.jsonl" ]; then
  _LAST_HEALTH=$(tail -1 "$_PROJ/health-history.jsonl" 2>/dev/null)
  echo "LAST_HEALTH: $_LAST_HEALTH"
fi

echo "---"
```

## Step 1: Detect Available Tools

Check which quality tools are available in this project:

```bash
# Test runner
# pytest: either pytest.ini alone (strong signal) OR pyproject.toml mentioning pytest.
# Grouping matters — `[ -f pytest.ini ] || [ -f pyproject.toml ] && grep ... && echo`
# parses as `((A || B) && grep) && echo`, which silently drops a standalone pytest.ini.
if [ -f "pytest.ini" ] || { [ -f "pyproject.toml" ] && grep -q "pytest" pyproject.toml 2>/dev/null; }; then
  echo "TEST: pytest"
fi
[ -f "jest.config.js" ] || [ -f "jest.config.ts" ] && echo "TEST: jest"
[ -f "vitest.config.ts" ] || [ -f "vitest.config.js" ] && echo "TEST: vitest"
grep -q '"test"' package.json 2>/dev/null && echo "TEST: npm test"

# Linter
command -v ruff >/dev/null && echo "LINT: ruff"
[ -f ".eslintrc.js" ] || [ -f ".eslintrc.json" ] || [ -f "eslint.config.js" ] && echo "LINT: eslint"
[ -f "biome.json" ] && echo "LINT: biome"

# Type checker
[ -f "tsconfig.json" ] && echo "TYPECHECK: tsc"
[ -f "mypy.ini" ] || grep -q "mypy" pyproject.toml 2>/dev/null && echo "TYPECHECK: mypy"
[ -f "pyrightconfig.json" ] && echo "TYPECHECK: pyright"

# Dead code
command -v vulture >/dev/null && echo "DEADCODE: vulture"
command -v knip >/dev/null && echo "DEADCODE: knip"
```

Report which tools were detected and which are missing.

## Step 2: Run Each Check

For each detected tool, run it and capture results:

### Tests
```bash
# Python
python -m pytest --tb=short -q 2>&1 | tail -5
# or
npm test 2>&1 | tail -10
```
Parse: total tests, passed, failed, skipped.

### Linter
```bash
# Python
ruff check . --output-format=concise 2>&1 | tail -5
# or
npx eslint . --format compact 2>&1 | tail -5
```
Parse: total issues, errors, warnings.

### Type checker
```bash
# TypeScript
npx tsc --noEmit 2>&1 | tail -5
# or
mypy . 2>&1 | tail -5
```
Parse: total errors.

### Dead code
```bash
vulture . 2>&1 | wc -l
# or
npx knip 2>&1 | tail -10
```
Parse: number of dead code findings.

## Step 3: Compute Scores

Score each tool 0-10:

### Test score
- 10: All tests pass, >80% coverage (if measurable)
- 8: All tests pass, coverage unknown
- 5: Some tests fail (<10%)
- 2: Many tests fail (>10%)
- 0: Tests don't run / no tests exist

### Lint score
- 10: Zero errors, zero warnings
- 8: Zero errors, <10 warnings
- 5: <5 errors
- 2: 5-20 errors
- 0: >20 errors or linter doesn't run

### Typecheck score
- 10: Zero type errors
- 8: <5 type errors
- 5: 5-20 type errors
- 2: 20-50 type errors
- 0: >50 type errors or checker doesn't run

### Dead code score
- 10: Zero findings
- 8: <5 findings
- 5: 5-15 findings
- 2: 15-30 findings
- 0: >30 findings

### Weighted composite
```
composite = (test * 0.30) + (lint * 0.25) + (typecheck * 0.25) + (deadcode * 0.20)
```

If a tool is missing, redistribute its weight equally to the remaining tools.

## Step 4: Display Dashboard

**Follow `references/verification-gate.md`** — scores must reflect the runs from Step 2, not memory. Surface the provenance (timestamp or run-marker per tool) in the dashboard so the user can see the evidence is fresh.

```
## Code Health Dashboard

| Check | Tool | Score | Details |
|-------|------|-------|---------|
| Tests | pytest | 8/10 | 142 passed, 0 failed, 3 skipped |
| Lint | ruff | 9/10 | 0 errors, 4 warnings |
| Types | mypy | 7/10 | 8 type errors |
| Dead Code | vulture | 10/10 | 0 findings |

### Composite Score: 8.4/10 ████████░░

Evidence: scores reflect runs from this session — pytest @ 15:30:02, ruff @ 15:30:04, mypy @ 15:30:07, vulture @ 15:30:11.

### Trend
Previous: 7.8/10 (Apr 5)
Change: +0.6 ▲ improving
```

## Step 5: Persist Results

Append to health history:

```bash
echo '{"ts":"2026-04-07T15:30:00Z","branch":"'"$_BRANCH"'","composite":8.4,"test":8,"lint":9,"typecheck":7,"deadcode":10}' >> "$_PROJ/health-history.jsonl"
```

## Step 6: Recommendations

Based on the scores, provide the top 3 actionable recommendations:

```
## Recommendations

1. **Fix type errors** (typecheck: 7/10) — 8 errors in auth/ and models/. Run `mypy auth/ models/` to see details.
2. **Address lint warnings** (lint: 9/10) — 4 warnings, mostly unused imports. Run `ruff check . --fix` for auto-fix.
3. **Add test coverage** (tests: 8/10) — Consider adding tests for the new auth middleware.
```

## Step 7: Wrap Up

```bash
lsdlc-timeline-log '{"skill":"health","event":"completed","branch":"'"$_BRANCH"'","outcome":"DONE","composite":8.4,"session":"'"$_SESSION_ID"'"}' 2>/dev/null
```

```
STATUS: DONE
SUMMARY: Health score 8.4/10 (▲ from 7.8). Top issue: 8 type errors in auth/models.
```
