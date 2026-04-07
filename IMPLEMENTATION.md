# Worth

A terminal-based AI assistant built on Elixir/BEAM.

## What

Single-user, terminal-native AI assistant. One central brain operating across multiple workspaces. Can write code and do general research. Extensible through a skills system with self-learning. Connects to the world through MCP.

## Docs

| Doc | Description |
|-----|-------------|
| [vision.md](vision.md) | What worth is and why it exists |
| [architecture.md](architecture.md) | System architecture, dependency graph, component overview |
| [beam-architecture.md](beam-architecture.md) | Supervision tree, ETS/:persistent_term strategy, telemetry, PubSub, error handling |
| [database-layer.md](database-layer.md) | Ash + AshPostgres analysis, coexistence with mneme, skill lifecycle modeling |
| [memory.md](memory.md) | Unified global memory, workspace overlays, knowledge lifecycle |
| [brain.md](brain.md) | The central brain GenServer, callbacks, system prompt assembly |
| [workspaces.md](workspaces.md) | Workspace model, types, lifecycle, directory structure |
| [skills.md](skills.md) | Agent Skills standard, self-learning lifecycle, trust levels |
| [kits.md](kits.md) | JourneyKits integration: workflow registry, install, publish |
| [mcp.md](mcp.md) | MCP integration: broker, tools, resources, config |
| [ui.md](ui.md) | TermUI layout, Elm components, events, slash commands |
| [tools.md](tools.md) | Tool registry: builtin, memory, skill, gateway, MCP |
| [config.md](config.md) | File layout, config schema, workspace config |
| [project-structure.md](project-structure.md) | Source code layout, module responsibilities |
| [implementation-strategy.md](implementation-strategy.md) | Phased plan with deliverables |
| [risks.md](risks.md) | Risks, mitigations, design decisions |
| [testing.md](testing.md) | Test structure, patterns, infrastructure, per-phase coverage |
| [appendix-skills-research.md](appendix-skills-research.md) | Skills research: agentskills.io, self-learning, risks |
| [appendix-mcp-research.md](appendix-mcp-research.md) | MCP research: spec, hermes_mcp, ecosystem |
