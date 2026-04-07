# Worth

A terminal-based AI assistant built on Elixir/BEAM.

## What

Single-user, terminal-native AI assistant. One central brain operating across multiple workspaces. Can write code and do general research. Extensible through a skills system with self-learning. Connects to the world through MCP.

## Getting Started

```bash
mix deps.get
mix setup
mix test
```

## Usage

```bash
mix run --no-halt            # Start worth with default workspace
mix worth -w my-project      # Start with a specific workspace
```

## Docs

| Doc | Description |
|-----|-------------|
| [vision.md](docs/vision.md) | What worth is and why it exists |
| [architecture.md](docs/architecture.md) | System architecture, dependency graph, component overview |
| [beam-architecture.md](docs/beam-architecture.md) | Supervision tree, ETS/:persistent_term strategy, telemetry, PubSub |
| [database-layer.md](docs/database-layer.md) | Ash + AshPostgres analysis, coexistence with mneme |
| [memory.md](docs/memory.md) | Unified global memory, workspace overlays, knowledge lifecycle |
| [brain.md](docs/brain.md) | The central brain GenServer, callbacks, system prompt assembly |
| [workspaces.md](docs/workspaces.md) | Workspace model, types, lifecycle, directory structure |
| [skills.md](docs/skills.md) | Agent Skills standard, self-learning lifecycle, trust levels |
| [kits.md](docs/kits.md) | JourneyKits integration |
| [mcp.md](docs/mcp.md) | MCP integration: broker, tools, resources, config |
| [ui.md](docs/ui.md) | TermUI layout, Elm components, events, slash commands |
| [tools.md](docs/tools.md) | Tool registry: builtin, memory, skill, gateway, MCP |
| [config.md](docs/config.md) | File layout, config schema, workspace config |
| [project-structure.md](docs/project-structure.md) | Source code layout |
| [implementation-strategy.md](docs/implementation-strategy.md) | Phased plan with deliverables |
| [risks.md](docs/risks.md) | Risks and mitigations |
| [testing.md](docs/testing.md) | Test structure and patterns |
