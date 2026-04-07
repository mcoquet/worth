# Worth

A terminal-based AI assistant built on Elixir/BEAM.

## What

Single-user, terminal-native AI assistant. One central brain operating across multiple workspaces. Can write code and do general research. Extensible through a skills system with self-learning. Connects to the world through MCP.

## Docs

| Doc | Description |
|-----|-------------|
| [vision.md](docs/vision.md) | What worth is and why it exists |
| [architecture.md](docs/architecture.md) | System architecture, dependency graph, component overview |
| [beam-architecture.md](docs/beam-architecture.md) | Supervision tree, ETS/:persistent_term strategy, telemetry, PubSub, error handling |
| [database-layer.md](docs/database-layer.md) | Ash + AshPostgres analysis, coexistence with mneme, skill lifecycle modeling |
| [memory.md](docs/memory.md) | Unified global memory, workspace overlays, knowledge lifecycle |
| [brain.md](docs/brain.md) | The central brain GenServer, callbacks, system prompt assembly |
| [workspaces.md](docs/workspaces.md) | Workspace model, types, lifecycle, directory structure |
| [skills.md](docs/skills.md) | Agent Skills standard, self-learning lifecycle, trust levels |
| [kits.md](docs/kits.md) | JourneyKits integration: workflow registry, install, publish |
| [mcp.md](docs/mcp.md) | MCP integration: broker, tools, resources, config |
| [ui.md](docs/ui.md) | TermUI layout, Elm components, events, slash commands |
| [tools.md](docs/tools.md) | Tool registry: builtin, memory, skill, gateway, MCP |
| [config.md](docs/config.md) | File layout, config schema, workspace config |
| [project-structure.md](docs/project-structure.md) | Source code layout, module responsibilities |
| [implementation-strategy.md](docs/implementation-strategy.md) | Phased plan with deliverables |
| [risks.md](docs/risks.md) | Risks, mitigations, design decisions |
| [testing.md](docs/testing.md) | Test structure, patterns, infrastructure, per-phase coverage |
| [appendix-skills-research.md](docs/appendix-skills-research.md) | Skills research: agentskills.io, self-learning, risks |
| [appendix-mcp-research.md](docs/appendix-mcp-research.md) | MCP research: spec, hermes_mcp, ecosystem |

---

## Implementation Progress

### Phase 1: Skeleton & Core Loop -- COMPLETE

**Deliverable:** `worth` starts, shows a terminal chat, you type a question, it streams a response.

| Step | Status | Files |
|------|--------|-------|
| Mix project setup with dependencies | Done | `mix.exs`, `config/*.exs` |
| `Worth.Application` -- supervision tree | Done | `lib/worth/application.ex` |
| `Worth.Config` -- runtime config loading | Done | `lib/worth/config.ex` |
| `Worth.Repo` -- Ecto Repo for Mneme | Done | `lib/worth/repo.ex` |
| `Worth.UI.Root` -- Elm Architecture TUI component | Done | `lib/worth/ui/root.ex` |
| `Worth.Brain` -- GenServer, AgentEx integration | Done | `lib/worth/brain.ex`, `lib/worth/brain/supervisor.ex` |
| `Worth.LLM` -- multi-provider adapter (Anthropic, OpenAI, OpenRouter) | Done | `lib/worth/llm.ex`, `lib/worth/llm/*.ex` |
| `Worth.CLI` -- CLI entry point | Done | `lib/worth/cli.ex` |
| `Worth.Telemetry` -- telemetry span helper | Done | `lib/worth/telemetry.ex` |
| `Worth.Error` -- structured error type | Done | `lib/worth/error.ex` |
| `Worth.Workspace.Service` -- workspace CRUD | Done | `lib/worth/workspace/service.ex` |
| `Worth.Workspace.Context` -- system prompt assembly | Done | `lib/worth/workspace/context.ex` |
| `Worth.Persistence.Transcript` -- JSONL backend | Done | `lib/worth/persistence/transcript.ex` |
| System prompt template | Done | `priv/prompts/system.md` |
| Test infrastructure (DataCase, BrainCase) | Done | `test/support/*.ex`, `test/worth_test.exs` |
| Dependencies resolve and compile clean | Done | 0 warnings in worth code |

**Key decisions made during implementation:**

1. **TermUI API**: Uses `use TermUI.Elm` with `init/1`, `event_to_msg/2`, `update/2`, `view/1` callbacks. Rendering uses `text/2`, `box/2`, `stack/2` (imported from `TermUI.Component.Helpers`). Styles built with `Style.from/1` (not `Style.new/1`). App started via `TermUI.Runtime.run(root: module)`.

2. **mneme dependency override**: mneme is a path dep for worth but a git dep for agent_ex. Added `override: true` in worth's mix.exs to resolve the conflict.

3. **Brain async execution**: Brain delegates AgentEx.run to Task.Supervisor to keep the GenServer responsive. Agent events flow back via `send/2` to the UI process.

4. **Polling for events**: The UI polls for brain events every 100ms via `Command.interval/2`, using a non-blocking `receive after 0` pattern. This avoids needing a direct PID coupling between Brain and UI.

### Phase 2: Workspaces & File Tools -- COMPLETE

**Deliverable:** `worth -w my-project` opens in the project directory, agent can read and edit files.

| Step | Status | Files |
|------|--------|-------|
| `Worth.Workspace.Service` -- init, list, switch, create workspaces | Done | `lib/worth/workspace/service.ex` |
| Workspace scaffolding (IDENTITY.md, AGENTS.md, .worth/skills.json) | Done | `lib/worth/workspace/service.ex` |
| Brain switches to `:agentic` profile for code mode | Done | `lib/worth/brain.ex` (mode_to_profile/1) |
| agent_ex's core file tools available via default `:execute_tool` | Done | (inherited from agent_ex) |
| `Worth.Workspace.Context` -- system prompt assembly | Done | `lib/worth/workspace/context.ex` |
| `Worth.Brain` -- mode switching, workspace switching, tool permissions | Done | `lib/worth/brain.ex` |
| Tool permission system (`:on_tool_approval` callback) | Done | `lib/worth/brain.ex` (build_callbacks) |
| `Worth.Tools.Web` -- web_fetch, web_search | Done | `lib/worth/tools/web.ex` |
| `Worth.Tools.Git` -- git_diff, git_log, git_status | Done | `lib/worth/tools/git.ex` |
| `Worth.Tools.Workspace` -- workspace_status, workspace_list, workspace_switch | Done | `lib/worth/tools/workspace.ex` |
| `Worth.Persistence.Transcript` -- JSONL append per turn | Done | `lib/worth/persistence/transcript.ex` |
| UI: tool call/result rendering (blue >> tool, magenta << result) | Done | `lib/worth/ui/root.ex` (message_to_nodes) |
| UI: sidebar with workspace/tools/status tabs (Tab to toggle) | Done | `lib/worth/ui/root.ex` (render_sidebar) |
| UI: command history (Up/Down arrows) | Done | `lib/worth/ui/root.ex` (history_prev/next) |
| UI: header with mode indicator, turn counter, cost | Done | `lib/worth/ui/root.ex` (render_header) |
| Slash commands: /mode, /workspace list/switch/new, /status | Done | `lib/worth/ui/root.ex` (parse_command) |
| CLI: --mode flag, --init flag | Done | `lib/worth/cli.ex` |
| Tests: workspace service, brain switching | Done | `test/worth/workspace_test.exs`, `test/worth/brain_test.exs` |

**Key decisions made during implementation:**

1. **Mode/profile mapping**: `:code` -> `:agentic`, `:research` -> `:conversational`, `:planned` -> `:agentic_planned`, `:turn_by_turn` -> `:turn_by_turn`. Brain translates user-facing modes to agent_ex profiles.

2. **Tool permissions**: `bash` and `write_file` require approval by default. Everything else is auto-approved. The `:on_tool_approval` callback sends a notification to the UI and auto-approves for now (full human-in-the-loop approval UI comes in Phase 5).

3. **Worth-specific tools** (web_fetch, git_diff, etc.) are defined as extension modules with `definitions/0` and `execute/3` functions. They'll be registered as agent_ex extensions when wiring up the full tool pipeline (Phase 3/4).

4. **Event draining**: The UI polls every 50ms and drains ALL pending events in one batch. This avoids event buildup and ensures tool_call/tool_result messages appear inline in the chat.

5. **System prompt assembly**: `Worth.Workspace.Context.build_system_prompt/1` merges the base prompt (`priv/prompts/system.md`) with workspace identity files (IDENTITY.md, AGENTS.md).

### Phase 3: Unified Memory -- NOT STARTED

**Deliverable:** Agent recalls prior conversations across all workspaces, extracts and persists facts globally.

### Phase 4: Skills & Research Mode -- NOT STARTED

**Deliverable:** agentskills.io-compatible skill system with self-learning foundation.

### Phase 5: Self-Learning Skills & Polish -- NOT STARTED

**Deliverable:** Self-learning skills with full lifecycle, multi-provider, polished UX.

### Phase 6: MCP Integration -- NOT STARTED

**Deliverable:** Agent can connect to MCP servers, discover tools, execute them.

### Phase 7: Advanced Features -- NOT STARTED

**Deliverable:** Worth as MCP server, codebase indexing, sub-agents, JourneyKits integration.
