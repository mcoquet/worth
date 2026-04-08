# Worth

A terminal-based AI assistant built on Elixir/BEAM. Worth provides a modular, embeddable agent system with persistent memory, self-learning skills, and MCP integration.

[![License](https://img.shields.io/badge/license-BSD--3--Clause-blue.svg)](LICENSE)
[![Elixir](https://img.shields.io/badge/Elixir-1.19+-grey.svg)](https://elixir-lang.org)
[![BEAM](https://img.shields.io/badge/BEAM-OTP-26+-grey.svg)](https://www.erlang.org)

## Why Elixir/BEAM?

Worth runs on the BEAM virtual machine—the same platform powering WhatsApp, Discord, and Heroku. BEAM provides:

- **Process isolation** — Each MCP server, tool execution, and agent turn runs in its own lightweight process. Failures are contained.
- **Supervision trees** — Built-in fault tolerance. A crashed MCP connection restarts without killing the agent.
- **Hot code upgrades** — Reload modules without restarting. Worth can evolve while running.
- **Real-time concurrency** — Streaming LLM responses, tool execution, and UI updates happen concurrently without callback hell.

Worth is a single BEAM node. No containers, no VMs, no web server required.

## Quick Start

### As a Library

Add Worth to your `mix.exs`:

```elixir
def deps do
  [
    {:worth, "~> 0.1.0"},
    {:agent_ex, path: "../agent_ex"},  # Local dependency
    {:mneme, path: "../mneme"}          # Local dependency
  ]
end
```

### As a Standalone Application

```bash
# Clone and setup
git clone https://github.com/kittyfromouterspace/worth.git
cd worth
mix setup

# Configure API keys
export ANTHROPIC_API_KEY="sk-ant-..."

# Run the TUI
mix run --no-halt
```

## Core Concepts

### The Brain

`Worth.Brain` is a GenServer that orchestrates the agent loop. It owns the session state and delegates to specialized subsystems:

```elixir
# Start a session with custom callbacks
{:ok, brain} = Worth.Brain.start_link(
  workspace: "my-project",
  mode: :code,
  callbacks: custom_callbacks
)

# Send a message
{:ok, response} = Worth.Brain.send_message(brain, "Write a test for auth.ex")
```

The brain exposes these integration points:
- `send_message/2` — Send user input, get agent response
- `approve_tool/2` — Approve a pending tool call
- `switch_workspace/2` — Change context
- `switch_mode/2` — Change agent autonomy (`:code`, `:research`, `:planned`, `:turn_by_turn`)

### Memory System

Worth uses [Mneme](https://github.com/kittyfromouterspace/mneme) for vector search + knowledge graph:

```elixir
# Store a fact (global, not per-workspace)
Worth.Memory.Manager.write(%{
  content: "User prefers conventional commits",
  entry_type: "preference",
  metadata: %{workspace: "my-project"}
})

# Search global knowledge
{:ok, results} = Worth.Memory.Manager.search("commit conventions")
```

Memory is **global** by design. All workspaces share one knowledge store. Workspaces provide context overlays (project identity, local skills), not memory silos.

### Skills System

Skills follow the [agentskills.io](https://agentskills.io/) standard and teach the agent *how* to use tools:

```elixir
# List available skills
skills = Worth.Skill.Service.list()

# Read skill content
{:ok, skill} = Worth.Skill.Service.read("git-workflow")

# Create a new skill
Worth.Skill.Service.create(%{
  name: "my-skill",
  description: "Custom skill instructions",
  body: "# Instructions..."
})
```

Skills have trust levels: `core` (shipped), `installed` (user-added), `learned` (agent-created). The system tracks success rates and auto-refines underperforming skills.

### MCP Integration

Worth can connect to external MCP servers and expose its own capabilities as an MCP server.

**As an MCP Client:**

```elixir
# Configure in ~/.worth/config.exs
%{
  mcp: %{
    servers: %{
      github: %{
        type: "stdio",
        command: "npx",
        args: ["-y", "@modelcontextprotocol/server-github"],
        env: %{"GITHUB_TOKEN" => {:env, "GITHUB_TOKEN"}},
        autoconnect: true
      }
    }
  }
}
```

**As an MCP Server:**

```bash
# Run worth as an MCP server
mix worth serve
```

Exposed tools: `worth_chat`, `worth_memory_query`, `worth_skill_list`, `worth_workspace_status`

## Integration APIs

### Embedding the Agent

```elixir
# Start with custom configuration
config = %{
  llm: %{
    provider: :anthropic,
    model: "claude-sonnet-4-20250514",
    api_key: {:env, "ANTHROPIC_API_KEY"}
  },
  cost_limit: 10.0,
  workspace: "my-project"
}

{:ok, brain} = Worth.Brain.start_link(config: config)

# Stream responses
Worth.Brain.send_message(brain, "Refactor user.ex", fn event ->
  case event do
    {:text_chunk, text} -> IO.puts(text)
    {:tool_call, tool} -> IO.inspect(tool, label: "Tool call")
    {:done, _} -> IO.puts("\n--- Done ---")
  end
end)
```

### Custom Tools

Register tools that the agent can call:

```elixir
defmodule MyApp.Tools.Custom do
  @behaviour AgentEx.Tools

  def name, do: "my_custom_tool"
  def description, do: "Does something useful"

  def schema do
    %{
      name: "my_custom_tool",
      description: "Does something useful",
      inputSchema: %{
        type: "object",
        properties: %{
          input: %{type: "string", description: "Input value"}
        },
        required: ["input"]
      }
    }
  end

  def execute(args, _ctx) do
    {:ok, %{result: "processed: #{args.input}"}}
  end
end

# Register it
AgentEx.Tools.register_extension(MyApp.Tools.Custom)
```

### Custom LLM Adapter

Worth supports Anthropic, OpenAI, and OpenRouter. To add a new provider:

```elixir
defmodule MyApp.LLM.MyProvider do
  @behaviour Worth.LLM.Adapter

  @impl true
  def chat(messages, config) do
    # Call your LLM API
    # Return normalized response:
    %{
      "content" => [...],
      "stop_reason" => "end_turn",
      "usage" => %{input_tokens: 100, output_tokens: 50},
      "cost" => 0.003
    }
  end
end

# Configure in ~/.worth/config.exs
%{
  llm: %{
    default_provider: :my_provider,
    providers: %{
      my_provider: %{
        adapter: MyApp.LLM.MyProvider,
        api_key: {:env, "MY_PROVIDER_KEY"},
        default_model: "my-model"
      }
    }
  }
}
```

### Extending the Brain

Provide custom callbacks to modify agent behavior:

```elixir
callbacks = %{
  # Custom LLM call
  llm_chat: fn params ->
    MyApp.LLM.call(params)
  end,

  # Custom memory lookup
  knowledge_search: fn query, opts ->
    MyApp.Memory.search(query, opts)
  end,

  # Custom tool resolution
  get_tool_schema: fn name ->
    MyApp.Tools.resolve(name)
  end,

  # Before/after each turn
  on_turn_start: fn ctx ->
    Logger.info("Starting turn in #{ctx.workspace}")
    ctx
  end,

  on_turn_end: fn ctx, result ->
    Logger.info("Turn complete, cost: #{result.cost}")
    :ok
  end
}

Worth.Brain.start_link(callbacks: callbacks)
```

## Architecture

```
┌─────────────────────────────────────────────────────────┐
│                    Worth (BEAM Node)                      │
│                                                          │
│  ┌──────────────┐    ┌──────────────┐                   │
│  │  TermUI       │    │  Brain       │                   │
│  │  (Elm Arch)   │◄──►│  (GenServer) │                   │
│  │              │    │              │                     │
│  │  - Input     │    │  - AgentEx   │                    │
│  │  - Render    │    │  - Mneme     │                    │
│  │  - Events    │    │  - Skills    │                    │
│  └──────────────┘    │  - MCP       │                    │
│                      └──────┬───────┘                    │
│                             │                            │
│                      ┌──────▼───────┐                    │
│                      │  AgentEx     │                    │
│                      │  Loop Engine │                    │
│                      └──────┬───────┘                    │
│                             │                            │
│        ┌─────────────┬──────┼──────┬─────────────┐      │
│        │             │      │      │             │      │
│ ┌──────▼──┐  ┌──────▼──┐  ┌──▼──┐  ┌──────▼──┐  ┌─▼────┐│
│ │ Mneme   │  │ File    │  │Tool │  │ Skills  │  │ MCP  ││
│ │ Memory  │  │ Tools   │  │Index│  │ System  │  │Servers│
│ └──────┬──┘  └─────────┘  └─────┘  └─────────┘  └───────┘│
│        │                                              │
│ ┌──────▼──┐                                          │
│ │PostgreSQL│                                         │
│ │+ pgvector│                                         │
│ └─────────┘                                         │
└─────────────────────────────────────────────────────────┘
```

### Key Modules

| Module | Responsibility |
|--------|----------------|
| `Worth.Brain` | Central GenServer, coordinates agent loop |
| `Worth.LLM` | Provider abstraction (Anthropic, OpenAI, OpenRouter) |
| `Worth.Memory.Manager` | Global memory orchestration |
| `Worth.Skill.Service` | Skill CRUD, lifecycle management |
| `Worth.Mcp.Broker` | DynamicSupervisor for MCP connections |
| `Worth.Mcp.Gateway` | Lazy tool discovery and execution |
| `Worth.Tools` | Builtin tool implementations |
| `Worth.UI.Root` | TermUI Elm Architecture root |

### Supervision Tree

```
Worth.Application
├── Worth.Repo (Ecto/Postgres + pgvector)
├── Worth.Config (Agent)
├── Phoenix.PubSub + Worth.Registry
├── Worth.TaskSupervisor
├── Worth.Telemetry
├── Worth.Mcp.Broker (DynamicSupervisor)
├── Worth.Mcp.ConnectionMonitor
├── Worth.Brain.Supervisor
│   └── Worth.Brain (GenServer)
└── Worth.UI (separate process tree)
```

## Prerequisites

- **Elixir** 1.19+
- **PostgreSQL** 14+ with pgvector extension
- **LLM API key** (Anthropic, OpenAI, or OpenRouter)

### Database Setup

```bash
# Create database
mix ecto.create

# Run migrations
mix ecto.migrate
```

Or with Docker:

```bash
docker run -d \
  --name worth-db \
  -e POSTGRES_PASSWORD=worth \
  -e POSTGRES_DB=worth \
  -v pgdata:/var/lib/postgresql/data \
  -p 5432:5432 \
  pgvector/pgvector:pg16
```

## Configuration

Worth reads from `~/.worth/config.exs` (auto-created on first run):

```elixir
%{
  # LLM Configuration
  llm: %{
    default_provider: :anthropic,
    cost_limit: 5.0,  # Max dollars per session
    providers: %{
      anthropic: %{
        api_key: {:env, "ANTHROPIC_API_KEY"},
        default_model: "claude-sonnet-4-20250514"
      },
      openai: %{
        api_key: {:env, "OPENAI_API_KEY"},
        default_model: "gpt-4o"
      },
      openrouter: %{
        api_key: {:env, "OPENROUTER_API_KEY"},
        default_model: "anthropic/claude-3.5-sonnet"
      }
    }
  },

  # UI Theme
  ui: %{
    theme: :dark  # :dark | :light | :minimal
  },

  # MCP Servers
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

## Development

```bash
# Install dependencies
mix deps.get

# Setup database
mix setup

# Run tests
mix test

# Linting
mix credo

# Type checking
mix dialyzer

# Run the TUI
mix run --no-halt
```

### Running Tests

```bash
# Full test suite (creates test DB automatically)
mix test

# Single file
mix test test/worth/brain_test.exs

# Single test
mix test test/worth/brain_test.exs:42
```

## Slash Commands

When running the TUI, these commands are available:

| Command | Description |
|---------|-------------|
| `/help` | Show all commands |
| `/mode <mode>` | Switch mode: code, research, planned, turn_by_turn |
| `/workspace switch <name>` | Switch to a workspace |
| `/memory query <query>` | Search global memory |
| `/skill list` | List all skills |
| `/session resume <id>` | Resume a past session |
| `/mcp list` | List connected MCP servers |

## Workspaces

A workspace is a project directory with identity files:

```
my-project/
├── IDENTITY.md              # Project description (read each turn)
├── AGENTS.md                # Agent-specific instructions
└── .worth/
    ├── skills.json          # Active skills for this workspace
    └── mcp.json             # MCP server overrides
```

## Documentation

Full design docs in `docs/`:

| Document | Description |
|----------|-------------|
| [vision.md](docs/vision.md) | What worth is and why it exists |
| [architecture.md](docs/architecture.md) | System architecture and dependencies |
| [brain.md](docs/brain.md) | Brain GenServer and callback system |
| [memory.md](docs/memory.md) | Global memory: vector search + knowledge graph |
| [skills.md](docs/skills.md) | Skill system, trust levels, self-learning |
| [mcp.md](docs/mcp.md) | MCP client/server integration |
| [tools.md](docs/tools.md) | Available tools and extensions |

## Dependencies

Worth depends on two local libraries that must exist as siblings:

- **`../agent_ex`** — Agent loop engine with stages, profiles, and tool system
- **`../mneme`** — Vector search + knowledge graph for memory

Other key dependencies:

| Library | Purpose |
|---------|---------|
| `term_ui` | Elm Architecture TUI framework |
| `hermes_mcp` | MCP client/server (JSON-RPC 2.0) |
| `ash` + `ash_postgres` | Domain modeling and persistence |
| `phoenix_pubsub` | Event broadcasting |
| `req` | HTTP client for LLM APIs |

## License

BSD-3-Clause. See [LICENSE](LICENSE) for details.

## Contributing

Contributions welcome. Please ensure:
- `mix credo` passes (linting)
- `mix dialyzer` passes (types)
- Tests pass (`mix test`)