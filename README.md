# linear-sdlc

A complete SDLC workflow for teams using Linear + Claude Code. Ticket-driven development with specialist code reviews, knowledge accumulation, and quality monitoring.

## Install

Paste this into Claude Code:

```
Install linear-sdlc: run git clone --single-branch --depth 1 https://github.com/<org>/linear-sdlc.git ~/.claude/skills/linear-sdlc && cd ~/.claude/skills/linear-sdlc && ./setup then add a "Linear SDLC" section to CLAUDE.md that says to use the Linear MCP server for all issue management, and lists the available skills: /brainstorm, /create-tickets, /next, /implement, /checkpoint, /health. Then ask the user if they also want to add linear-sdlc to the current project so teammates get it.
```

### Prerequisites

- **Node.js** (for Linear MCP server)
- **GitHub CLI** (`gh`) for PR creation
- **Git**
- **Linear API key** (Settings → API → Personal API keys)

## Skills

| Skill | Description |
|-------|-------------|
| `/brainstorm` | Plan new features, search for duplicates, write specs |
| `/create-tickets` | Convert spec files into Linear issues with dependencies |
| `/next` | Query Linear for unblocked tickets, recommend what to work on |
| `/implement` | Full lifecycle: ticket → branch → code → specialist review → PR |
| `/checkpoint` | Save/resume working state across sessions |
| `/health` | Code quality dashboard with composite scoring |

## Workflow

### New feature
```
/brainstorm → write spec → /create-tickets → /implement each ticket
```

### Existing ticket
```
/next → pick ticket → /implement VER-42
```

### During work
```
/checkpoint → save state → (new session) → /checkpoint → resume
/health → check code quality score
```

## How It Works

- **Linear MCP Server** — All Linear operations (create issues, update status, search) go through the `@anthropic-ai/linear-mcp-server` MCP server, configured automatically during setup.
- **Specialist Reviews** — Before PR creation, parallel sub-agents review the diff for testing gaps, security issues, performance problems, and code quality.
- **Knowledge Base** — Learnings are logged as JSONL during work. After enough observations accumulate on a topic, they're synthesized into wiki pages for future reference.
- **Timeline** — Every skill execution is logged locally for context recovery across sessions.

## Configuration

Config lives at `~/.linear-sdlc/config.json`:

```json
{
  "linear_team_id": "VER"
}
```

Manage with: `~/.claude/skills/linear-sdlc/bin/lsdlc-config get|set|list`

## State Directory

```
~/.linear-sdlc/
├── config.json
├── .onboarding-complete
└── projects/{slug}/
    ├── learnings.jsonl
    ├── timeline.jsonl
    ├── health-history.jsonl
    ├── wiki/
    └── checkpoints/
```

## License

MIT
