# Changelog

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
