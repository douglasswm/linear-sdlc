---
name: wiki
description: |
  Manage the project wiki — a persistent, LLM-maintained knowledge base that
  lives in the user's repo. Subcommands: init, ingest, query, lint, sync,
  sync-linear, linear-setup, ingest-source, migrate, qmd-setup, qmd-refresh.
  Use when: "wiki", "document this", "file this answer", "ingest this",
  "what does the wiki say about X", "/wiki init".
model: sonnet
effort: medium
argument-hint: "<subcommand> [args]"
allowed-tools:
  - Bash
  - Read
  - Write
  - Edit
  - Glob
  - Grep
  - AskUserQuestion
---

# /wiki — Manage the project wiki

The wiki is a persistent, LLM-authored knowledge base that lives at
`<repo>/.linear-sdlc/wiki/` (or `~/.linear-sdlc/projects/<slug>/wiki/` under
`wiki_scope=private`). Claude is the author; the user reviews diffs.

See `<wiki>/CLAUDE.md` for the full schema once the wiki is initialized.

## Preamble

Run this first:

```bash
# Bootstrap: resolve LINEAR_SDLC_ROOT from this skill's symlink, then source
# the shared preamble (safe env loader + project detection + session tracking).
if [ -z "${LINEAR_SDLC_ROOT:-}" ]; then
  for _c in "$HOME/.claude/skills/wiki/SKILL.md" \
            "$HOME/.claude/skills/linear-sdlc-wiki/SKILL.md"; do
    if [ -L "$_c" ]; then
      LINEAR_SDLC_ROOT="$(cd "$(dirname "$(readlink "$_c")")/../.." && pwd)"
      break
    fi
  done
  [ -z "${LINEAR_SDLC_ROOT:-}" ] && LINEAR_SDLC_ROOT="$(lsdlc-config get source_dir 2>/dev/null || true)"
  export LINEAR_SDLC_ROOT
fi
SKILL_NAME=wiki . "$LINEAR_SDLC_ROOT/references/preamble.sh"

echo "---"
```

## Dispatching subcommands

Read the argument the user passed and route to the matching section below.

If no subcommand was provided, print the list and ask what they want:

```
/wiki subcommands:
  init           Scaffold the wiki in this repo
  ingest <arg>   Synthesize a source into wiki pages (ticket ID, --incident, --source, --learning)
  query <q>      Search the wiki and synthesize an answer, optionally file it back
  lint           Structural health check with suggested fixes
  sync           Resolve working-tree merge conflicts semantically
  sync-linear    Push wiki pages to the configured Linear Project
  linear-setup   Interactive Linear Project picker + enable sync
  ingest-source <path>  Import an external file (article, transcript, PDF) and synthesize
  migrate        Import legacy home-dir wiki into sources/legacy/
  qmd-setup      Register wiki as a qmd search collection (optional, hybrid search)
  qmd-refresh    Reindex qmd collection manually
```

---

## `/wiki init`

Scaffold a new wiki in the current repo.

```bash
lsdlc-wiki init
```

After it prints the "Wiki initialized at ..." line, report:
- The path it created
- A one-line summary of what's inside (`CLAUDE.md`, `index.md`, `log.md`,
  subdirectories)
- Next steps: "Run `/implement <ticket>` or `/wiki ingest <ticket-id>` to
  start filling it, or `/wiki qmd-setup` to enable hybrid search."

Do **not** auto-commit. Leave the new files in the working tree.

---

## `/wiki ingest <arg>`

The **fan-out** write path. This is where Claude does real synthesis work.

Supported argument forms:
- `<TICKET-ID>` (e.g., `VER-42`) — pull the ticket from Linear and the
  current branch's diff.
- `--incident <slug>` — use with `/debug`; summarize a completed debug
  session.
- `--source <path>` — ingest an external file previously dropped into
  `sources/`. Use `/wiki ingest-source <path>` for new files that haven't
  been moved into `sources/` yet.
- `--learning <key>` — promote a private learning into a wiki page.

### Ingest workflow (applies to all forms)

Follow the workflow from `<wiki>/CLAUDE.md` exactly:

1. **Read the source.**
   - Ticket: `lsdlc-linear get-issue <ID>` + `git diff main...HEAD`
   - Incident: read `incidents/<slug>.md` if it already exists, otherwise
     consult the /debug session notes
   - External file: read the file under `sources/...`
2. **Read `<wiki>/index.md`** to find related pages.
3. **Read the related entity and concept pages** you expect to touch.
4. **Draft the primary page** in the appropriate subdirectory
   (`tickets/<ID>.md`, `incidents/<slug>.md`, or `concepts/<topic>.md`).
5. **Draft updates to related entity/concept pages.** This is the fan-out —
   you should expect to touch 3–10+ pages per ingest.
6. **Insert contradiction callouts** where new claims disagree with old text:
   ```markdown
   > **⚠ Contradiction noted:** Previously this page said *"X"* (sourced
   > from <ref>, <date>). New evidence from <new ref>, <date> says *"Y"*.
   > Needs human review.
   ```
   Never silently overwrite existing claims.
7. **Run `lsdlc-wiki secret-scan <draft-file>` on EVERY draft** before
   writing. Exit code 3 means abort the **entire** ingest (no partial
   writes). If a draft contains a secret, discard all drafts, tell the user
   which file triggered it, and stop.
8. **Write all drafts.**
9. **Update `index.md`** via `lsdlc-wiki index-upsert <page-path>
   <category> <one-line-summary>` for each new or changed page. Category
   is one of: `Entities`, `Concepts`, `Tickets`, `Incidents`, `Queries`,
   `Sources`.
10. **Append to `log.md`** via `lsdlc-wiki log-append ingest "<title>"
    --touched <comma-separated-rel-paths>`.
11. **Print a summary** listing every touched file, then remind the user
    that everything is in the working tree and they should review before
    committing.

### Auto-indexing (if qmd is installed)

After the writes, if `wiki_qmd_auto_index=true`:
```bash
lsdlc-wiki qmd-refresh &
```
Run in the background so the user doesn't wait.

---

## `/wiki query <question>`

Read-mostly. Produces an answer with citations, then offers to file the
answer back as a new `queries/<slug>.md` page.

1. `lsdlc-wiki search "<question-terms>"` — auto-routed to qmd when
   available, grep otherwise. Parse the JSON result.
2. Read the top 3–5 matching pages in full (via the `Read` tool).
3. Synthesize the answer with inline relative-markdown citations:
   `[authentication](../entities/auth.md) uses JWT tokens...`.
4. Note any gaps you spotted during the walk (missing concept pages, terms
   referenced without links, TODO markers).
5. Print the answer.
6. Use `AskUserQuestion` to offer filing it back:
   - "Save this answer as a wiki page for future reference?"
   - Options: "Yes (queries/<slug>.md)" / "No, skip"
7. On yes:
   - Derive a kebab-case slug from the question
   - Secret-scan the draft (`lsdlc-wiki secret-scan`)
   - Write `queries/<slug>.md`
   - `lsdlc-wiki index-upsert queries/<slug>.md Queries "<question>"`
   - `lsdlc-wiki log-append query-filed "<question>" --touched queries/<slug>.md`
8. If you noticed structural gaps, print a one-line hint at the end:
   "Noted potential gaps — run `/wiki lint` to see the full list."

---

## `/wiki lint`

Run the structural report and explain each finding in plain language.

```bash
lsdlc-wiki lint
```

Parse the output. Group findings by severity:

1. **Contradictions** (highest) — explain each, offer to investigate.
   **Never auto-resolve.** Only a human (or a targeted follow-up ingest)
   should remove a contradiction callout.
2. **Broken references** — offer to fix or mark for archival. Per-fix
   confirmation via `AskUserQuestion`.
3. **Orphan pages** — offer to add them to `index.md` or link them from a
   related page.
4. **Stale pages** — check whether referenced files have changed in git
   since the `updated:` timestamp. If yes, propose a re-ingest.
5. **Data gaps (TODO/FIXME)** — surface the open questions for the user.

Summarize the health at the end: "Wiki is healthy" / "Wiki has N high-
priority issues" / etc. Report the lint run via
`lsdlc-wiki log-append lint "<summary>"`.

---

## `/wiki sync`

Resolve wiki conflicts in the working tree after a `git pull` or branch
merge.

1. Check `git status --porcelain` for files under the wiki path with `UU`
   (both modified) status.
2. For each conflicted file, read both sides and re-synthesize the page
   by combining the information. Do **not** do line-level conflict marker
   cleanup — think of this as a small ingest pass that merges two branches
   of the same knowledge.
3. Secret-scan each merged draft before writing.
4. Run `git add <merged-file>` on each file the user confirms is ready.
5. Append a log entry: `lsdlc-wiki log-append sync "resolved <N> conflicts"
   --touched ...`.

If there are no conflicts, report "No wiki conflicts" and exit.

---

## `/wiki sync-linear`

Push wiki pages to the configured Linear Project as Documents. One-way
(git → Linear), never pull.

1. Verify `wiki_linear_project_id` is set:
   ```bash
   lsdlc-config get wiki_linear_project_id
   ```
   If empty, run `/wiki linear-setup` instead.
2. Run a dry-run first:
   ```bash
   lsdlc-wiki sync-linear --dry-run
   ```
3. Show the user the plan (N creates, M updates) via `AskUserQuestion`:
   "Push these changes to Linear?"
4. On yes:
   ```bash
   lsdlc-wiki sync-linear
   ```
5. Report the outcome. If any page was blocked by secret-scan, name it and
   tell the user to fix the content.
6. `lsdlc-wiki log-append sync-linear "pushed <N> pages" --touched ...`

---

## `/wiki linear-setup`

Interactive one-time setup for Linear sync.

1. Run `lsdlc-linear list-projects` to fetch available Projects.
2. Parse the JSON output. Use `AskUserQuestion` to let the user pick one.
   Include "Create a new Project" as an option at the end.
3. If the user picked an existing project, grab its UUID from the JSON.
   If the user picked "Create a new Project":
   - Ask for a project name (`AskUserQuestion`, free-form).
   - Run `lsdlc-linear create-project --name "<name>" --team "<team>"`
     where `<team>` is `$(lsdlc-config get linear_team_id)`.
   - Parse `project.id` from the JSON output — that's the new UUID.
4. Save the UUID:
   ```bash
   lsdlc-config set wiki_linear_project_id <uuid>
   lsdlc-config set wiki_linear_sync true
   ```
5. Run a dry-run sync to confirm credentials and show the initial plan:
   ```bash
   lsdlc-wiki sync-linear --dry-run
   ```
6. Ask the user if they want to enable auto-sync on every ingest:
   - "Auto-sync to Linear on every wiki write?"
   - Options: "No (Recommended) — manual /wiki sync-linear" / "Yes — auto"
7. On yes: `lsdlc-config set wiki_linear_auto_sync true`

---

## `/wiki ingest-source <path>`

Import an external file and kick off a fan-out synthesis pass.

1. Verify the file exists.
2. Run `lsdlc-wiki ingest-source <path>` — this copies the file into the
   appropriate `sources/` subdirectory and appends a log entry. It also
   prints a `DIRECTIVE_TO_CLAUDE:` line.
3. Follow the directive: read the imported file from its new location,
   then run the full `/wiki ingest` workflow with `--source <new-path>`.
4. The LLM is doing the synthesis work; the CLI only moves files and logs.

Supported types: `.md`, `.txt`, `.pdf` (read the text content), `.html`,
images (view them with the Read tool and describe into a summary page).

---

## `/wiki migrate`

Import legacy home-dir wiki content for users upgrading from older
linear-sdlc versions.

1. Run `lsdlc-wiki migrate`. It copies `~/.linear-sdlc/projects/<slug>/wiki/*`
   into `<wiki>/sources/legacy/` non-destructively (originals are left in
   place).
2. If any legacy files were imported, offer to run `/wiki ingest --source
   sources/legacy/<file>` on each one to integrate the content into live
   entity/concept pages. Use `AskUserQuestion` for batch confirmation.
3. When the user confirms the migration worked, remind them they can
   `rm -rf ~/.linear-sdlc/projects/<slug>/wiki` to reclaim space.

---

## `/wiki qmd-setup`

Enable the hybrid BM25 + vector + LLM-reranking search tier.

1. Check whether `qmd` is on `PATH`:
   ```bash
   command -v qmd
   ```
2. If not installed:
   - Print the install one-liner: `npm install -g @tobilu/qmd`
   - Print a note about the optional MCP-server upgrade path (one-time
     `claude mcp add ...`) for the most seamless integration.
   - Exit.
3. If installed:
   ```bash
   lsdlc-wiki qmd-setup
   ```
   This registers the wiki as a qmd collection named `linear-sdlc-<slug>`,
   runs the initial `qmd update` + `qmd embed`, and flips
   `wiki_search_backend=qmd`.
4. Run a smoke-test search to confirm it works:
   ```bash
   lsdlc-wiki search "<something-in-the-wiki>"
   ```
   Verify the output's `backend` field says `grep` or `qmd` as expected.

---

## `/wiki qmd-refresh`

Manual reindex (normally runs in the background after ingests).

```bash
lsdlc-wiki qmd-refresh --embed
```

The `--embed` flag regenerates vectors (slower, run occasionally).
Without it, only the BM25 index is updated.

---

## Error handling

If any subcommand reports the wiki is not initialized, offer to run
`/wiki init` first.

If `lsdlc-wiki secret-scan` exits 3 during an ingest, the ingest MUST be
aborted entirely. Do not write any page. Report the secret location and
ask the user to fix the source. This is non-negotiable.

If `lsdlc-wiki sync-linear` fails for individual pages, continue with the
rest but report failures clearly. Never retry more than once.
