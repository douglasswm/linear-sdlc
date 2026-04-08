# Changelog

## v2.1.0 — 2026-04-09 — Hardening pass + one-prompt install

A follow-up cleanup on v2.0.0 that addresses a round of deferred review items and adopts gstack's one-prompt install style.

### Security

- **Stopped `.`-sourcing `~/.linear-sdlc/env`.** The env file lives in a user-writable directory; shell-sourcing it would execute any code a compromised process wrote into it. The shared preamble now parses the `LINEAR_API_KEY=` line in pure shell (mirroring the pure-JS parser `bin/lsdlc-linear` was already using) and refuses to read the file if it's group/other-writable or not owned by the current user. No skill ever evaluates the file's contents.

### Additions

- **One-prompt install.** The README now has a gstack-style "Install — 30 seconds" section with a verbatim prompt you paste into Claude Code. Claude clones the repo, runs `./setup --skip-api-key --skip-mcp-prompt` for the mechanical parts, and adds a `linear-sdlc` section to `~/.claude/CLAUDE.md`. The secrets step (API key + team ID) is then done in a real terminal so credentials never flow through chat history.
- **`bin/lsdlc-linear` accepts team UUIDs.** The `--team` flag now auto-detects UUID format (`07877f05-4f32-42b4-a2df-9e1764316652`) vs the short team key (`VER`) and builds the correct GraphQL filter (`team: { id: ... }` vs `team: { key: ... }`). Previously the helper filtered by key unconditionally, which silently returned nothing when a user had stored a UUID in `linear_team_id`. New helpers `teamFilter()` / `teamMatches()` / `isUuid()` are at the top of the file — future team-filtering code should call them. Setup's team-ID regex accepts both forms.
- **Shared preamble at `references/preamble.sh`.** The parts of the preamble that every skill needs identically (env loader, branch/project detection, session tracking) are now in a single sourced file. Each `SKILL.md` carries a tiny ~14-line bootstrap that resolves `$LINEAR_SDLC_ROOT` from its own symlink and then `.`-sources `preamble.sh`. The security-critical env loader can no longer drift across skills. Skills still keep their own info-display blocks (learnings, wiki, checkpoints, last-health) inline after sourcing.
- **`lsdlc-config unset` subcommand.** Removes a key from `config.json`. Used for one-shot migrations and generally useful for tests. Charset-validated the same way `get`/`set` are.

### Fixes

- **`/health` standalone `pytest.ini` detection.** The previous shell chain `[ -f "pytest.ini" ] || [ -f "pyproject.toml" ] && grep -q "pytest" pyproject.toml && echo "TEST: pytest"` parsed as `((A || B) && grep) && echo` under POSIX left-associative precedence — a project with only `pytest.ini` and no `pyproject.toml` was silently undetected. Rewritten as an explicit `if` block so intent survives. The other similar-looking chains (`jest.config.*`, `vitest.config.*`, `.eslintrc.*`, `mypy.ini || grep`) are actually correct under left-associative evaluation and were left alone.
- **README uninstall handles the `--prefix` toggle.** The old snippet listed only the short skill names with a "if you used `--prefix`, substitute manually" footnote. Replaced with a `for` loop that removes both forms unconditionally.

### Docs

- **New `## See it work` section in README.md.** A scripted seven-command walkthrough of a real ticket thread — `/brainstorm rate limiting` → `/create-tickets` → `/next` → `/implement VER-103` → `/debug` → `/health` → `/checkpoint` — showing what each skill actually prints, including the security specialist catching a missing per-IP bound mid-review. Written in the gstack "See it work" tradition; the flow is specific to linear-sdlc's ticket-driven lifecycle, not borrowed text.
- **New `## The sprint` section in README.md.** Frames linear-sdlc as a process (**Plan → Ticket → Pick → Build → Review → Reflect**), with a specialist table where each skill gets a role (Product Manager, Project Manager, Scrum Lead, Staff Engineer, Debugger, Session Memory, Quality Lead). Explains how the hand-offs work, why `~/.linear-sdlc/projects/<slug>/` is "the thread," and the **ticket-first, not branch-first** invariant.
- **Old `## Skills` table and per-skill `## Usage` subsections replaced with a compact `## Model and effort defaults` table.** The content overlapped heavily with the new "The sprint" specialist table — merged into a single reference table carrying only the unique model/effort/why information.
- **`references/preamble.md`** rewritten to describe the bootstrap + sourced split and point at `preamble.sh` as the authoritative version.
- **`CLAUDE.md`** expanded with a new "Preamble: bootstrap + shared source" section, a drift-guard grep (`grep -rn 'LINEAR_API_KEY' skills/` should return zero), and a note that future team-filtering code must use `teamFilter()` / `teamMatches()` rather than hardcoding `key`.
- **`README.md`** now mentions the team UUID format, the safe env parser, the shared preamble, and the `unset` subcommand.

## v2.0.0 — 2026-04-08 — Skills pack revert; direct GraphQL by default

linear-sdlc is no longer a Claude Code plugin. v1's plugin packaging caused recurring setup pain (MCP reconnect failures, `userConfig` interpolation fighting `/doctor`, brittle dependency on a specific `npx -y` MCP package). v2 reverts to the gstack-style skills pack model — `git clone` + `./setup` — and uses direct Linear GraphQL via a new bundled helper. The official Linear MCP server is now an optional install the user runs themselves.

### Breaking changes

- **Distribution model.** No longer a plugin. Install via:
  ```bash
  git clone git@github.com:douglasswm/linear-sdlc.git ~/.claude/skills/linear-sdlc
  cd ~/.claude/skills/linear-sdlc
  ./setup
  ```
  See README → "Migrating from v1" for the upgrade path. v1 users must `/plugin uninstall linear-sdlc@linear-sdlc` first.
- **API key location.** Moves from the OS keychain (plugin `userConfig`) to `~/.linear-sdlc/env` (mode `0600`), sourced by the skill preamble. Alternatives — 1Password CLI, direnv, exporting from your shell rc — are documented in the README.
- **Skill names default to short.** `/brainstorm`, `/next`, `/implement`, `/create-tickets`, `/checkpoint`, `/debug`, `/health`. Opt back into namespaced names with `./setup --prefix` (which gives `/linear-sdlc-brainstorm`, etc. — note the dash, not the v1 colon).

### Additions

- **`setup` script** at the repo root, modeled on `gstack/setup`. Idempotent, interactive, prompts for skill prefix / API key / team key. Validates the install. Handles re-runs safely.
- **`bin/lsdlc-linear`** — zero-dependency Node helper wrapping Linear's GraphQL API. Subcommands: `whoami`, `search-issues`, `list-assigned`, `get-issue`, `set-status`, `create-issue`, `add-relation`. Reads `LINEAR_API_KEY` from `process.env` (with a fallback to parsing `~/.linear-sdlc/env` in pure JS — never shell-source). The API key never appears on argv or in error output. Every Linear operation linear-sdlc skills perform now goes through this helper.
- **ETHOS.md principle:** "Depend on Official Integrations" — codifies why we prompt users to install Linear's MCP separately rather than embedding it.

### Removals

- **`.claude-plugin/` directory** (`plugin.json`, `marketplace.json`, `mcp.json`).
- **Embedded `@anthropic-ai/linear-mcp-server` reference.** linear-sdlc no longer ships or registers an MCP server. `setup` prints instructions for installing Linear's first-party HTTP MCP (`claude mcp add --transport http linear https://mcp.linear.app/mcp`) but never installs it automatically. Skills do not depend on the MCP being present — they use direct GraphQL via `lsdlc-linear`.
- **All "Use the Linear MCP server" natural-language instructions** in skill bodies (replaced with concrete `lsdlc-linear` Bash invocations and inline `node -e` parsing snippets).
- **`${CLAUDE_PLUGIN_ROOT}` reference** in `skills/brainstorm/SKILL.md` Step 5 (replaced with `$LINEAR_SDLC_ROOT/templates/spec-template.md`, where `$LINEAR_SDLC_ROOT` is exported by the preamble).

### Preserved

- **`~/.linear-sdlc/projects/{slug}/` state layout is unchanged.** Learnings, timelines, checkpoints, wiki pages, per-branch review files from v1 all carry over intact.
- **All `bin/lsdlc-*` scripts** (slug, config, timeline-log, learnings-log, learnings-search, wiki-ingest, wiki-lint) — they were always portable; setup now wires them onto PATH via `~/.local/bin` symlinks.
- **`skills/implement/specialists/`** — sub-agent checklists are unchanged. The `/implement` skill still dispatches them as parallel sub-agents via the `Agent` tool.
- **All seven skill model/effort defaults.** `/brainstorm` Opus/medium, `/implement` Sonnet/medium, etc.

## v1.0.1 — 2026-04-08 — /doctor warning fix

### Fixed
- **Moved MCP config from `.mcp.json` to `.claude-plugin/mcp.json`.** Claude Code's project-scope `.mcp.json` scanner was picking up the plugin's MCP config from the repo root and emitting a bogus `Missing environment variables: user_config.linear_api_key` warning in `/doctor`, because that scanner doesn't understand plugin userConfig interpolation. The plugin loader still finds the file via the updated `mcpServers` path in `plugin.json`, so install, enable, and the Linear MCP server all behave identically — only the spurious warning is gone.

## v1.0.0 — 2026-04-08 — Plugin release

linear-sdlc is now a Claude Code plugin. This is the first tagged release.

### What it looks like
- **Namespaced invocation.** Skills are called as `/linear-sdlc:brainstorm`, `/linear-sdlc:implement`, `/linear-sdlc:debug`, `/linear-sdlc:checkpoint`, `/linear-sdlc:health`, `/linear-sdlc:create-tickets`, `/linear-sdlc:next`.
- **Plugin-based install.** `/plugin marketplace add git@github.com:douglasswm/linear-sdlc.git` then `/plugin install linear-sdlc@linear-sdlc`.
- **Secrets in the OS keychain.** Linear API key is collected at plugin enable time via `userConfig` and stored in macOS Keychain / Linux Secret Service / Windows Credential Manager. Never in plaintext config files.
- **Zero setup script.** The old `./setup` bash ritual is gone.

### Known untested
- **Marketplace install over SSH from a private repo.** Public repos are the supported path; private repos should work via `git@…` but haven't been verified.

### Pre-v1.0.0 history
The repo went through a skill-pack era (git clone + `./setup` + symlinks) before this release. That era had no tagged releases and no known external users. If you find a pre-v1.0.0 reference in this repo's git history, it belongs to that era and is not supported.
