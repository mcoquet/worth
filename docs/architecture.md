# Architecture Overview

## System Diagram

```
┌─────────────────────────────────────────────────────────┐
│                    Worth (BEAM Node)                      │
│                                                          │
│  ┌──────────────┐    ┌──────────────┐                   │
│  │  TermUI       │    │  Brain       │                   │
│  │  (Elm Arch)   │◄──►│  (GenServer) │                   │
│  │              │    │              │                     │
│  │  - Input     │    │  - AgentEx   │                    │
│  │  - Render    │    │    .run/1    │                     │
│  │  - Events    │    │  - Mneme     │                    │
│  │              │    │  - Skills    │                    │
│  └──────────────┘    │  - Workspaces│                    │
│                      │  - MCP       │                    │
│                      └──────┬───────┘                    │
│                             │                            │
│                      ┌──────▼───────┐                    │
│                      │  AgentEx     │                    │
│                      │  Loop Engine │                    │
│                      │              │                    │
│                      │  Stages:     │                    │
│                      │  ContextGuard│                    │
│                      │  LLMCall     │                    │
│                      │  ToolExecutor│                    │
│                      │  CommitGate  │                    │
│                      └──────┬───────┘                    │
│                             │                            │
│               ┌─────────────┼─────────────┐              │
│               │             │             │              │
│        ┌──────▼──┐  ┌──────▼──┐  ┌──────▼──┐           │
│        │ Mneme   │  │ File    │  │ Skills  │  │ MCP     │           │
│        │ Memory  │  │ Tools   │  │ System  │  │ Servers │            │
│        └──────┬──┘  └─────────┘  └─────────┘  └─────────┘           │
│               │                                           │
│        ┌──────▼──┐                                       │
│        │PostgreSQL│                                      │
│        │+ pgvector│                                      │
│        └─────────┘                                      │
└─────────────────────────────────────────────────────────┘
```

## Technical Stack

| Layer | Library | Role |
|-------|---------|------|
| UI | `term_ui` (~> 0.2.0) | Elm Architecture TUI framework, direct-mode rendering at 60fps |
| Agent Runtime | `agent_ex` (local path) | Composable pipeline loop engine with stages, profiles, tools |
| Memory | `mneme` (local path, via agent_ex) | Three-tier memory: working memory, knowledge graph, vector search |
| Database | PostgreSQL + pgvector | Single global database for mneme |
| MCP | `hermes_mcp` (~> 0.14.1) | MCP client/server, JSON-RPC 2.0, stdio + Streamable HTTP |
| HTTP | `req` (~> 0.5) | LLM API calls, embedding API calls, GitHub API |
| LLM | OpenRouter / Anthropic / OpenAI | Configurable provider routing |
| PubSub | `phoenix_pubsub` (~> 2.1) | Cross-component event broadcasting (no Phoenix dependency) |
| Domain Model | `ash` (~> 3.23) + `ash_postgres` (~> 2.8) | Skill lifecycle, kits, workspaces -- state machines, policies, code interfaces |
| Observability | `telemetry` + `telemetry_metrics` | Metrics: cost, tokens, latency, tool calls |
| Config | `nimble_options` | Compile-time config schema validation |
| CLI | `owl` | Rich terminal output outside the TUI |

## Dependency Graph

```
worth
├── term_ui          (hex)
├── agent_ex         (path: ../agent_ex)
│   └── mneme        (path: ../mneme, transitive)
│       ├── ecto_sql + postgrex + pgvector
│       └── req
├── hermes_mcp       (hex, ~0.14.1) -- also transitive via agent_ex
│   ├── finch        (HTTP client for Streamable HTTP transport)
│   ├── peri         (JSON Schema validation)
│   └── jason
├── phoenix_pubsub   (hex, ~> 2.1)
├── ash              (hex, ~> 3.23)
├── ash_postgres     (hex, ~> 2.8)
├── telemetry        (hex) -- already transitive via mneme
├── telemetry_metrics(hex)
├── nimble_options   (hex)
├── owl              (hex)
└── ecto_sql + postgrex   (worth owns the Repo)
```

## Key Architectural Principles

### One Brain

A single GenServer coordinates the agent loop. It delegates state to specialized stores (ETS, :persistent_term, PostgreSQL) rather than holding everything in its GenServer state. See [beam-architecture.md](beam-architecture.md) for the supervision tree and storage strategy.

### One Memory

One Mneme instance, one database, one `scope_id: "worth"`. Workspaces provide context boosts, not memory silos. See [memory.md](memory.md).

### Lazy Discovery

Tools, skills, and MCP integrations use progressive disclosure. Metadata is loaded always; full content is loaded on demand. This keeps token usage low regardless of how many tools/skills/integrations are installed.

### Elm Architecture

The UI follows TermUI's Elm Architecture: `init/update/view`. The Brain and UI communicate via messages (GenServer calls in, process casts out). Agent streaming events flow asynchronously to keep the UI responsive.

### Callback Composition

AgentEx's callback system provides clean separation. Worth provides integration callbacks (LLM, memory, tools, streaming) without modifying the loop engine. This means agent_ex improvements flow into worth automatically.

### Supervision & Fault Tolerance

Each subsystem has its own supervisor. An MCP server crash does not kill the UI. A memory flush failure does not kill the brain. See [beam-architecture.md](beam-architecture.md) for the full supervision tree.

### Observability

All subsystems emit `:telemetry` events. Worth consumes events from agent_ex (`[:agent_ex, ...]`), mneme (`[:mneme, ...]`), and its own (`[:worth, ...]`). Metrics drive the UI status bar (cost, tokens, latency) without polling. See [beam-architecture.md](beam-architecture.md) for the event hierarchy.
