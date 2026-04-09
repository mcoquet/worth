# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project

Worth is a terminal-based AI assistant built on Elixir/BEAM. It is a single OTP application that wraps an agent loop, a TUI, persistent memory, a self-learning skill system, and MCP client/server integration.

## Common commands

```bash
mix setup              # deps.get + ecto.create + ecto.migrate
mix test               # runs ecto.create/migrate then full test suite
mix test path/to/file_test.exs            # single file
mix test path/to/file_test.exs:LINE       # single test
mix compile
mix credo              # lint
mix dialyzer           # type check
mix run --no-halt                         # start TUI (default workspace, code mode)
mix run --no-halt -- -w NAME -m MODE      # workspace + mode (code|research|planned|turn_by_turn)
mix run --no-halt -- --init NAME          # scaffold a workspace and exit
mix worth                                 # alias for the TUI launcher
```

Database: PostgreSQL **with the pgvector extension** is required (used by Mneme for vector search). Tests automatically run `ecto.create --quiet && ecto.migrate --quiet` before executing (see `mix.exs` aliases).

Two unusual deps live as **path dependencies** outside this repo and must exist as siblings of `worth/`:
- `../agent_ex` — the agent loop engine (`AgentEx.run/1`)
- `../mneme` — vector search + knowledge graph backing memory

## Architecture

The system is organized around a single coordinator GenServer (`Worth.Brain`) that owns one agent session at a time and dispatches into subsystem services. The TUI is a separate process tree that talks to the Brain over message passing.

### Supervision tree

`Worth.Application` (lib/worth/application.ex) starts, in order:
1. `Worth.Repo` (Ecto/Postgres + pgvector)
2. `Worth.Config` (Agent holding runtime config loaded from `~/.worth/config.exs`)
3. `Phoenix.PubSub` (`Worth.PubSub`) and `Worth.Registry`
4. `Worth.TaskSupervisor`, `Worth.Telemetry`
5. `Worth.Mcp.Broker` (DynamicSupervisor for MCP server connections) and `Worth.Mcp.ConnectionMonitor`
6. `Worth.Brain.Supervisor`
7. After boot: async `Worth.Skill.Registry.init/0` and `Worth.Mcp.Broker.connect_auto/0` via a `SkillInit` task supervisor

### Brain → agent loop

`Worth.Brain` (lib/worth/brain.ex) is a named GenServer holding `current_workspace`, `session_id`, `history`, `mode`, `tool_permissions`, `pending_approval`, etc. It exposes a sync API (`send_message/1`, `approve_tool/1`, `switch_mode/1`, `switch_workspace/1`, `resume_session/1`, …) that the UI and slash commands call. Each turn invokes `AgentEx.run/1` which iterates LLM ↔ tool calls. Tool permissions are per-tool `:auto` or `:approve` (see `@default_tool_permissions`); approval-gated tools park in `pending_approval` until the UI calls `approve_tool/deny_tool`.

Modes (code, research, planned, turn_by_turn) change the agent's prompt + autonomy profile, not its toolset.

### Subsystems (each is a small service called from the Brain)

- **lib/worth/llm/** — `Adapter` behaviour with `Anthropic`, `OpenAI`, `OpenRouter` implementations and a `Router` that picks primary vs lightweight models. `Cost` tracks per-turn dollars against `cost_limit`.
- **lib/worth/memory/** — `Memory.Manager` orchestrates retrieval against Mneme (vector + knowledge graph). `FactExtractor` pulls facts from agent turns. Memory is **global**, shared across all workspaces; working memory per workspace is flushed to global on switch.
- **lib/worth/skills/** — Skills are agentskills.io-compatible `SKILL.md` files with `trust_level` ∈ {core, installed, learned}.
  - `Parser`/`Validator` parse + statically check skills
  - `Registry` caches metadata in `:persistent_term` + ETS index, init runs async at boot
  - `Service` is the CRUD façade
  - `Lifecycle` drives CREATE → TEST → REFINE → PROMOTE
  - `Refiner` does reactive (failure-driven) and proactive (every ~20 uses) refinement via the LLM
  - `Evaluator` tracks success rates; `Versioner` enables rollback; `Trust` enforces provenance
  - Core skills are bundled in `priv/core_skills/`
- **lib/worth/mcp/** — MCP integration built on `hermes_mcp`.
  - `Broker` (DynamicSupervisor) supervises one client per configured server; `ConnectionMonitor` does health checks + reconnect
  - `Registry` maps server name → client PID
  - `ToolIndex` maps tool name → server name; tools are namespaced as `server:tool_name` to avoid collisions
  - `Gateway` is the lazy discovery + execution path the agent calls
  - `server.ex` exposes Worth itself as an MCP server (`worth serve`) with tools like `worth_chat`, `worth_memory_query`, `worth_skill_list`
  - `Config` loads server definitions from `~/.worth/config.exs` + per-workspace `.worth/mcp.json`
- **lib/worth/tools/** — Worth-specific tools the agent can call: `workspace`, `git`, `web`, `memory`, `skills`, `kits`, `mcp` (the gateway-bridging tool).
- **lib/worth/workspace/** — Workspace scaffolding and identity-file loading. A workspace is `~/.worth/workspaces/<name>/` with `IDENTITY.md`, `AGENTS.md`, `.worth/skills.json`, `.worth/mcp.json`. The agent re-reads identity files each turn.
- **lib/worth/kits/** — JourneyKits search/install/publish. Installing a kit drops skills into `~/.worth/skills/` and source files into the workspace.
- **lib/worth/persistence/** — JSONL transcript backend for sessions (resume via `/session resume <id>`).
- **lib/worth/ui/** — `Worth.UI.Root` is a `TermUI` Elm-architecture root. It subscribes to PubSub for streaming responses, tool traces, and approval prompts from the Brain. `Theme` defines color palettes.
- **lib/worth/cli.ex** — CLI option parsing for `mix run --no-halt -- …` and `mix worth`. Handles `--init`, `--workspace`, `--mode`. Ends by calling `TermUI.Runtime.run(root: Worth.UI.Root, …)`.
- **lib/mix/tasks/worth.ex** — `mix worth` Mix task that boots the app and delegates to `Worth.CLI.main/1`.

### Configuration

`Worth.Config` loads `~/.worth/config.exs` (Elixir map literal — see README for shape). It is created on first run. Provider API keys use `{:env, "VAR"}` tuples. MCP servers can be marked `autoconnect: true` to connect at boot via `Broker.connect_auto/0`.

## Conventions worth knowing

- The TUI and the Brain are decoupled — never call UI code from Brain handlers; emit via PubSub or send to `state.ui_pid`.
- MCP tools must always be referenced with their `server:tool` namespace inside `ToolIndex` and the gateway.
- Skill mutations should go through `Worth.Skill.Service` (not `Registry` directly) so versioning, validation, and the in-memory index stay coherent.
- Memory writes go through `Worth.Memory.Manager` so fact extraction, embedding, and confidence decay are applied consistently.
- New tools belong under `lib/worth/tools/` and are wired into the agent via the tool registry the Brain hands to `AgentEx.run/1`.

## Theme System

Worth has a theme system (`lib/worth/theme/`) that supports multiple visual themes. All UI components must use the theme system to ensure themes work correctly.

### Theme Architecture

- **Theme modules** (`lib/worth/theme/*.ex`) implement `Worth.Theme` behavior
- **ThemeHelper** (`lib/worth_web/components/theme_helper.ex`) provides `color/1` function
- **Themes**: Standard (default), Cyberdeck, Fifth Element
- Theme is stored in encrypted settings (`Worth.Settings`) and resolved via `Worth.Theme.Registry`

### UI Development Rules

1. **NEVER use hardcoded color classes** (e.g., `text-ctp-blue`, `bg-ctp-mantle`)
2. **ALWAYS use theme colors** via `color(:key)` helper
3. **Use string interpolation** in templates: `class={"flex #{color(:background)} #{color(:border)}"}`
4. **Define new color keys** in theme modules when adding new UI elements

### Available Color Keys

```elixir
# Core colors
:background, :surface, :surface_elevated, :border
:text, :text_muted, :text_dim
:primary, :secondary, :accent
:success, :error, :warning, :info

# Component colors
:button_primary, :button_secondary
:tab_active, :tab_inactive
:status_running, :status_idle, :status_error
:message_user_bg, :message_error_bg, :message_thinking_border, :message_system_bg
:input_placeholder, :input_disabled_bg, :input_disabled_text
```

### Correct Pattern

```elixir
# GOOD - uses theme
def chat_header(assigns) do
  ~H"""
  <header class={"flex #{color(:background)} #{color(:border)} border-b"}>
    <span class={color(:primary)}>worth</span>
  </header>
  """
end

# BAD - hardcoded colors
def chat_header(assigns) do
  ~H"""
  <header class="flex bg-ctp-mantle border-b border-ctp-surface0">
    <span class="text-ctp-blue">worth</span>
  </header>
  """
end
```

### Adding New Themes

1. Create `lib/worth/theme/my_theme.ex` implementing `Worth.Theme` behavior
2. Define all color keys in `colors/0` function
3. Add custom CSS in `css/0` function if needed
4. Register in `lib/worth/theme/registry.ex`

## Documentation

Design docs live in `docs/` — start with `vision.md`, `architecture.md`, `brain.md`, `memory.md`, `skills.md`, `mcp.md` for the big picture. `implementation-strategy.md` describes the 7-phase build plan.
