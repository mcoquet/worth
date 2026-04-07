# Worth

A terminal-based AI assistant built on Elixir/BEAM. One brain, multiple workspaces, persistent memory, self-learning skills, and MCP integration.

## Features

- **Terminal-native TUI** -- Elm Architecture UI with streaming responses, tool trace rendering, sidebar, and command history
- **Unified global memory** -- Facts, preferences, and patterns persist across sessions and workspaces via vector search + knowledge graph (Mneme)
- **Self-learning skills** -- Agentskills.io-compatible skill system that creates, refines, and promotes skills based on usage
- **MCP client** -- Connect to any MCP server (filesystem, GitHub, Postgres, Slack, etc.) and use its tools
- **MCP server** -- Expose worth's brain, memory, and skills to other MCP clients (Claude Desktop, VS Code, Cursor)
- **JourneyKits** -- Search, install, and publish packaged AI workflows
- **Multi-provider LLM** -- Anthropic, OpenAI, OpenRouter with primary/lightweight model routing
- **Multiple workspaces** -- Switch between projects with scoped context while sharing global knowledge
- **Multiple modes** -- Code (agentic), Research (conversational), Planned, Turn-by-turn

## Prerequisites

- Elixir 1.19+
- PostgreSQL 14+ with pgvector extension
- An LLM API key (Anthropic, OpenAI, or OpenRouter)

## Setup

```bash
# Clone
git clone <repo-url> worth && cd worth

# Install dependencies
mix deps.get

# Setup database (creates + migrates)
mix setup

# Set your API key
export ANTHROPIC_API_KEY="sk-ant-..."
```

### Database

Worth uses PostgreSQL with the pgvector extension for vector similarity search. Create the database:

```bash
# Install pgvector if you don't have it (macOS)
brew install pgvector

# Create database and run migrations
mix ecto.create
mix ecto.migrate
```

### Configuration

Worth reads config from `~/.worth/config.exs` (created automatically on first run). You can customize:

```elixir
# ~/.worth/config.exs
%{
  llm: %{
    default_provider: :anthropic,
    providers: %{
      anthropic: %{
        api_key: {:env, "ANTHROPIC_API_KEY"},
        default_model: "claude-sonnet-4-20250514"
      }
    }
  },
  ui: %{theme: :dark},              # :dark | :light | :minimal
  cost_limit: 5.0,                   # max dollars per session
  mcp: %{
    servers: %{
      filesystem: %{
        type: "stdio",
        command: "npx",
        args: ["-y", "@modelcontextprotocol/server-filesystem", "/home/user/projects"],
        autoconnect: true
      }
    }
  }
}
```

## Starting Worth

```bash
# Default workspace, code mode
mix run --no-halt

# Specific workspace
mix run --no-halt -- -w my-project

# Research mode
mix run --no-halt -- -m research

# Create a workspace and exit
mix run --no-halt -- --init my-project

# Planned mode (agent shows plan before executing)
mix run --no-halt -- -m planned
```

## Slash Commands

Inside worth's TUI, type `/` to access commands:

| Command | Description |
|---------|-------------|
| `/help` | Show all commands |
| `/quit` | Exit worth |
| `/clear` | Clear chat history |
| `/cost` | Show session cost and turn count |
| `/status` | Show mode, workspace, cost, session ID |
| `/mode <mode>` | Switch mode: `code` / `research` / `planned` / `turn_by_turn` |
| `/workspace list` | List all workspaces |
| `/workspace new <name>` | Create a workspace |
| `/workspace switch <name>` | Switch to a workspace |
| `/memory query <query>` | Search global memory |
| `/memory note <text>` | Add a note to working memory |
| `/memory recent` | Show recent memories |
| `/skill list` | List all skills (core, installed, learned) |
| `/skill read <name>` | Read a skill's full content |
| `/skill remove <name>` | Remove a skill |
| `/skill history <name>` | Show skill version history |
| `/skill rollback <name> <v>` | Roll back a skill to a previous version |
| `/skill refine <name>` | Trigger manual skill refinement |
| `/session list` | List past sessions |
| `/session resume <id>` | Resume a previous session |
| `/mcp list` | List connected MCP servers |
| `/mcp connect <name>` | Connect to a configured MCP server |
| `/mcp disconnect <name>` | Disconnect from a server |
| `/mcp tools <name>` | List tools from a server |
| `/kit search <query>` | Search JourneyKits for workflows |
| `/kit install <owner/slug>` | Install a kit (skills + files) |
| `/kit list` | List installed kits |
| `/kit info <owner/slug>` | Show kit details |

### Keyboard

| Key | Action |
|-----|--------|
| `Tab` | Toggle sidebar |
| `Up/Down` | Navigate command history |
| `Enter` | Submit message |
| `Backspace` | Delete character |

## Workspaces

A workspace is a project directory containing identity files and settings:

```
my-project/                  # Workspace root
├── IDENTITY.md              # Project description (read by agent)
├── AGENTS.md                # Agent-specific instructions
└── .worth/
    ├── skills.json          # Active skills for this workspace
    └── mcp.json             # MCP server overrides
```

The agent reads `IDENTITY.md` and `AGENTS.md` on each turn to understand the project context. You can put conventions, constraints, and preferences there.

## Memory

Worth has a single global knowledge store powered by Mneme (vector search + knowledge graph):

- **Automatic fact extraction** -- The agent extracts facts from responses and tool results
- **Working memory** -- Short-term notes per workspace, flushed to global memory on workspace switch
- **Vector search** -- Queries find semantically similar knowledge using embeddings
- **Confidence decay** -- Knowledge fades over time unless reinforced by usage
- **Outcome feedback** -- Successful agent turns reinforce relevant memories

Memory is shared across all workspaces. A pattern learned in one project is available everywhere.

## Skills

Skills teach the agent *how* to use tools. They follow the agentskills.io standard:

```
SKILL.md
---
name: my-skill
description: What this skill does
trust_level: core | installed | learned
loading: always | on_demand
---

# Instructions for the agent...
```

### Skill Lifecycle

1. **Core** -- Bundled with worth (agent-tools, human-agency, tool-discovery, skill-lifecycle, self-improvement)
2. **Installed** -- Installed from kits or manually by the user
3. **Learned** -- Created by the agent from experience or failure recovery
4. **Promoted** -- Learned skills that meet success criteria get promoted to installed

The agent automatically:
- Tracks skill success rates
- Refines failing skills (with LLM assistance)
- Runs proactive reviews every 20 uses
- Saves version history for rollback

### Bundled Core Skills

| Skill | Description |
|-------|-------------|
| `agent-tools` | File operations, bash commands, search |
| `human-agency` | Knowing when to ask for human input |
| `tool-discovery` | Finding and using available tools |
| `skill-lifecycle` | Creating and managing skills |
| `self-improvement` | Meta-skill for self-reflection |

## MCP Integration

### Connecting to MCP Servers

Add servers to `~/.worth/config.exs`:

```elixir
%{
  mcp: %{
    servers: %{
      github: %{
        type: "stdio",
        command: "npx",
        args: ["-y", "@modelcontextprotocol/server-github"],
        env: %{"GITHUB_PERSONAL_ACCESS_TOKEN" => {:env, "GITHUB_TOKEN"}},
        autoconnect: true
      },
      postgres: %{
        type: "stdio",
        command: "npx",
        args: ["-y", "@modelcontextprotocol/server-postgres", "postgresql://localhost/mydb"],
        autoconnect: false
      }
    }
  }
}
```

Or add workspace-specific servers in `.worth/mcp.json`:

```json
{
  "mcpServers": {
    "my-api": {
      "type": "streamable_http",
      "url": "http://localhost:8000",
      "mcp_path": "/mcp"
    }
  }
}
```

Servers with `autoconnect: true` connect on startup. Use `/mcp connect <name>` for others.

MCP tools are namespaced as `server:tool_name` to prevent collisions.

### Worth as MCP Server

Other MCP clients can connect to worth and use its capabilities:

```bash
# Run worth as an MCP server on stdio
worth serve
```

Exposed tools:
- `worth_chat` -- Send a message to the agent
- `worth_memory_query` -- Search the knowledge store
- `worth_memory_write` -- Store a fact
- `worth_skill_list` -- List all skills
- `worth_skill_read` -- Read skill content
- `worth_workspace_status` -- Current workspace info

## JourneyKits

Search and install packaged workflows:

```
/kit search phoenix deploy
/kit install worth-community/phoenix-deploy-flyio
/kit list
```

Installing a kit extracts bundled skills into `~/.worth/skills/` and writes source files to the current workspace.

## Development

```bash
# Run tests (120 tests)
mix test

# Compile
mix compile

# Run linting
mix credo

# Type checking
mix dialyzer
```

## Architecture

```
Worth Application
├── Worth.Brain (GenServer)        # Central coordinator
│   ├── AgentEx.run/1              # Agent loop engine
│   ├── Worth.Memory.Manager       # Global memory orchestration
│   ├── Worth.Skill.Service        # Skill CRUD
│   └── Worth.Mcp.Gateway          # MCP tool dispatch
├── Worth.UI.Root (TermUI)         # Elm Architecture TUI
├── Worth.Mcp.Broker (DynamicSup)  # MCP server connections
├── Worth.Mcp.ConnectionMonitor    # Health checks + reconnect
├── Worth.Repo (Ecto)              # PostgreSQL + pgvector
└── Worth.Config (Agent)           # Runtime config
```

## Documentation

Full design docs in `docs/`:

| Doc | Description |
|-----|-------------|
| [vision.md](docs/vision.md) | What worth is and why it exists |
| [architecture.md](docs/architecture.md) | System architecture and dependency graph |
| [memory.md](docs/memory.md) | Unified memory: working, knowledge, vector search |
| [skills.md](docs/skills.md) | Skill system, trust levels, self-learning |
| [mcp.md](docs/mcp.md) | MCP client/server integration |
| [brain.md](docs/brain.md) | Brain GenServer and callback system |
| [kits.md](docs/kits.md) | JourneyKits integration |
| [implementation-strategy.md](docs/implementation-strategy.md) | 7-phase implementation plan |

## License

MIT
