# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project

Worth is a personal AI assistant built on Elixir/BEAM with a Phoenix LiveView web UI, optionally shipped as a Tauri native desktop app. It is a single OTP application that wraps an agent loop, persistent memory, a self-learning skill system, multi-strategy orchestration, and MCP client/server integration.

## Common commands

```bash
mix setup              # deps.get + ecto.setup (both repos) + assets.setup + assets.build
mix test               # ecto.create/migrate for both repos, then full suite
mix test path/to/file_test.exs             # single file
mix test path/to/file_test.exs:LINE        # single test
mix compile
mix credo              # lint
mix dialyzer           # type check
mix ex_check           # run the full pre-commit bundle (credo, dialyzer, doctor, styler, etc.)

mix run --no-halt                          # start web UI (default workspace, code mode)
mix run --no-halt -- -w NAME -m MODE       # workspace + mode (code|research|planned|turn_by_turn)
mix run --no-halt -- --init NAME           # scaffold a workspace and exit
mix run --no-halt -- --setup               # run the interactive config wizard
mix worth                                  # alias for the web UI launcher
```

Desktop build: `./build.sh` mirrors the CI release workflow — it compiles an OTP release and wraps it with `cargo tauri build`. `./build.sh run` also launches the resulting binary.

### Databases

Worth uses **SQLite** via `ecto_sqlite3` with the `sqlite_vec` extension for vector search — **no Postgres required** (the project migrated away from pgvector). Two Ecto repos run side-by-side:

- `Worth.Repo` — primary app data (sessions, skills metadata, encrypted settings, Mneme memory)
- `Worth.Metrics.Repo` — separate DB for telemetry/metrics so heavy writes don't contend with app queries

`mix test` runs `ecto.create --quiet && ecto.migrate --quiet` for **both** repos before the suite (see `mix.exs` aliases).

Two deps live as **path dependencies** and must exist as siblings of `worth/` when `WORTH_DEPS_MODE=dev` (the default):

- `../agent_ex` — the agent loop engine (`AgentEx.run/1`) and the LLM provider/catalog/usage stack
- `../mneme` — vector search + knowledge graph backing memory

In `WORTH_DEPS_MODE=prod` the same libraries are pulled from GitHub at pinned tags (see `deps/0` in `mix.exs`).

## Architecture

The system is organized around per-workspace GenServers (`Worth.Brain`) that each own one agent session at a time and dispatch into subsystem services. The web UI is a Phoenix LiveView app (`WorthWeb.ChatLive`) that communicates with the Brain via PubSub events and GenServer calls.

### Supervision tree

`Worth.Application` (lib/worth/application.ex) starts, in order:

1. `Worth.Repo` (Ecto/SQLite + sqlite_vec)
2. `Worth.Config` (Agent holding runtime config loaded from `~/.worth/config.exs`)
3. `Worth.Vault` + `Worth.LogBuffer` (Cloak vault for encrypted columns + in-memory log ring)
4. `Phoenix.PubSub` (`Worth.PubSub`) and `Worth.Registry`
5. `Worth.TaskSupervisor`
6. `Worth.Metrics`, `Worth.Metrics.Repo`, `Worth.Metrics.Writer` (telemetry sink)
7. `Worth.Agent.Tracker`
8. `Worth.Mcp.Broker` (DynamicSupervisor for MCP servers) and `Worth.Mcp.ConnectionMonitor`
9. `Worth.Brain.Supervisor`
10. `Worth.Learning.TelemetryBridge` and `Worth.XRay.TelemetryBridge`
11. `Task.Supervisor` `Worth.SkillInit` (used for async boot tasks)
12. `WorthWeb.Telemetry`, `WorthWeb.Endpoint` (Bandit HTTP server)
13. `Worth.Desktop.Bridge` (shutdown/broadcast bridge for the Tauri shell)

After boot, the app kicks off async init tasks via `Worth.SkillInit`: skill registry init, MCP auto-connect, embeddings stale-check, coding-agent registration, LLM catalog refresh, and orchestration strategy registration.

When launched as the Tauri desktop app (`WORTH_DESKTOP=1`), `Worth.Boot.run_migrations_before_start!/0` runs Ecto migrations before the supervision tree starts.

### Brain → agent loop

`Worth.Brain` (lib/worth/brain.ex) is a per-workspace GenServer registered via `{:via, Registry, {Worth.Registry, {:brain, workspace}}}`. It holds `current_workspace`, `session_id`, `history`, `mode`, `tool_permissions`, `active_tools`, etc. It exposes a sync API (`send_message/2`, `get_status/1`, `switch_mode/2`, `switch_workspace/2`, `resume_session/2`, …) that takes a `workspace`/`session_id` argument. Each turn invokes `AgentEx.run/1` which iterates LLM ↔ tool calls. Tool permissions are per-tool `:auto` or `:approve`; approval-gated tools park in `pending_approval` until the UI calls `approve_tool`/`deny_tool`.

Modes (code, research, planned, turn_by_turn) change the agent's prompt + autonomy profile, not its toolset.

### Subsystems (each is a small service called from the Brain)

- **lib/worth/llm.ex** — `Worth.LLM` is a **thin dispatch shim** over `AgentEx.LLM`. All provider adapters, routing, failover, catalog, and usage tracking live in `agent_ex`. `Worth.LLM` only resolves the route → provider module + credentials and forwards. Don't re-introduce a worth-side `Adapter`/`Router`/`Cost` layer — those were deleted (see `BACKLOG.md` Phase 6).
- **lib/worth/memory/** — `Memory.Manager` orchestrates retrieval against Mneme (vector + knowledge graph). `FactExtractor` pulls facts from agent turns. `Memory.Embeddings.{Adapter,StaleCheck}` manage the embedding model side. Memory is **global**, shared across all workspaces; working memory per workspace is flushed to global on switch.
- **lib/worth/skill/** — Skills are agentskills.io-compatible `SKILL.md` files with `trust_level` ∈ {core, installed, learned}.
  - `Parser`/`Validator` parse + statically check skills
  - `Registry` caches metadata in `:persistent_term` + ETS index; init runs async at boot
  - `Service` is the CRUD façade — go through it, not `Registry` directly
  - `Lifecycle` drives CREATE → TEST → REFINE → PROMOTE
  - `Refiner` does reactive (failure-driven) and proactive (every ~20 uses) refinement via the LLM
  - `Evaluator` tracks success rates; `Versioner` enables rollback; `Trust` enforces provenance
  - Core skills are bundled in `priv/core_skills/`
- **lib/worth/mcp/** — MCP integration on `hermes_mcp`.
  - `Broker` (DynamicSupervisor) supervises one client per configured server; `ConnectionMonitor` does health checks + reconnect
  - `Registry` maps server name → client PID; `ToolIndex` maps tool name → server, with `server:tool_name` namespacing
  - `Gateway` is the lazy discovery + execution path the agent calls
  - `server.ex` exposes Worth itself as an MCP server with tools under `lib/worth/mcp/server/tools/` (`chat`, `memory_query`, `memory_write`, `skill_list`, `skill_read`, `workspace_status`)
  - `Config` loads server definitions from `~/.worth/config.exs` + per-workspace `.worth/mcp.json`
- **lib/worth/tools/** — Worth-specific tools the agent can call: `workspace`, `git`, `web`, `memory` (+ `memory/reembed`), `skills`, `kits`, `mcp`, and `router` (tool dispatch). `bash`/file-editing tools come from `agent_ex` with sandboxing.
- **lib/worth/workspace/** — Workspace scaffolding and identity-file loading. A workspace is `~/.worth/workspaces/<name>/` with `IDENTITY.md`, `AGENTS.md`, `.worth/skills.json`, `.worth/mcp.json`. `Context`, `Identity`, `Scanner`, `FileBrowser`, `Learning`, `Service` split the concerns. The agent re-reads identity files each turn.
- **lib/worth/kits.ex** + **lib/worth/tools/kits.ex** — JourneyKits search/install/publish. Installing a kit drops skills into `~/.worth/skills/` and source files into the workspace.
- **lib/worth/metrics/** — Telemetry sink. `Worth.Metrics` is the query API, `Metrics.Writer` batches telemetry events into `Worth.Metrics.Repo`, and `Metrics.Queries`/`Schema` define read-side aggregations (session cost, cache hits, provider totals).
- **lib/worth/learning/** — Per-project learning state: `AgentConfig`, `Checkpoint`, `Permissions`, `ProjectMapping`, `State`, `TelemetryBridge`. Tracks what the agent has learned about a project across sessions.
- **lib/worth/orchestration/** — Multi-agent strategies registered with `AgentEx.Strategy.Registry`: `stigmergy` (the one registered at boot), `holonic`, `ecosystem`, `evolutionary`, `swarm`. `Experiment`/`ExperimentService` drive experimental runs.
- **lib/worth/coding_agents.ex** — Registry of external coding CLIs (Claude Code, OpenCode, etc.). Maps per-OS config/log/cache directories that the sandbox grants access to, and auto-registers at boot.
- **lib/worth/desktop/bridge.ex** — PubSub bridge to the Tauri shell for shutdown broadcasts and other desktop-only events.
- **lib/worth/vault.ex** + **lib/worth/settings/** — `Worth.Vault` is a Cloak vault; `Worth.Settings` stores encrypted key/value settings (theme, master-password state, etc.) in `Worth.Repo`. `Settings.MasterPassword` handles lock/unlock for encrypted columns.
- **lib/worth/persistence/transcript.ex** — JSONL transcript backend for sessions (resume via `/session resume <id>`).
- **lib/worth/ui/commands.ex** — Pure command parser used by the LiveView. (The old TermUI TUI was replaced by Phoenix LiveView.)
- **lib/worth_web/** — Phoenix LiveView web UI. `WorthWeb.ChatLive` is the main LiveView. `WorthWeb.Router` serves it via Bandit. Components live in `lib/worth_web/components/` and command handlers in `lib/worth_web/live/commands/`.
- **lib/worth/cli.ex** — CLI option parsing for `mix run --no-halt -- …` and `mix worth`. Supports `--init`, `--workspace`, `--mode`, `--strategy`, `--setup`, `--no-open`. Delegates to `Worth.Boot.run/1` and opens the web UI in the browser.
- **lib/mix/tasks/worth.ex** — `mix worth` Mix task that boots the app and delegates to `Worth.CLI.main/1`.

### Configuration

`Worth.Config` loads `~/.worth/config.exs` (Elixir map literal — see README for shape). It is created on first run via `Worth.Config.Setup` (`mix run --no-halt -- --setup`). Provider API keys use `{:env, "VAR"}` tuples. MCP servers can be marked `autoconnect: true` to connect at boot via `Broker.connect_auto/0`. Encrypted settings (theme, etc.) live in `Worth.Settings` in the database, not in the config file.

### Sandboxing

File/shell tools always run through `AgentEx.Sandbox` (bubblewrap on Linux/WSL2, App Sandbox inheritance on macOS, restricted-token fallback on Windows). Path validation enforces an **allowlist of roots**: the active workspace + each registered coding-agent's own config/cache dirs (from `Worth.CodingAgents`). Worth's internal data directory (`~/.worth/worth.db`, vault) is never exposed. `AgentEx.Sandbox.Platform.log_status/0` runs at boot and warns if the sandbox is weaker than expected (e.g. Windows without WSL2).

## Conventions worth knowing

- The UI and the Brain are decoupled — never call UI code from Brain handlers; emit via PubSub. The LiveView subscribes to Brain events and renders them.
- MCP tools must always be referenced with their `server:tool` namespace inside `ToolIndex` and the gateway.
- Skill mutations go through `Worth.Skill.Service` (not `Registry` directly) so versioning, validation, and the in-memory index stay coherent.
- Memory writes go through `Worth.Memory.Manager` so fact extraction, embedding, and confidence decay are applied consistently.
- LLM calls go through `Worth.LLM` or (for background tasks that need tier+failover) `AgentEx.LLM.chat_tier/3` — don't call provider modules directly.
- New tools belong under `lib/worth/tools/` and are wired into the agent via the tool registry the Brain hands to `AgentEx.run/1`.
- `BACKLOG.md` is the authoritative todo list with rich context — check it before proposing cleanup items; many may already be marked resolved.

## Theme System

Worth has a theme system (`lib/worth/theme/`) that supports multiple visual themes. All UI components must use the theme system to ensure themes work correctly.

### Theme Architecture

- **Theme modules** (`lib/worth/theme/*.ex`) implement the `Worth.Theme` behaviour
- **ThemeHelper** (`lib/worth_web/components/theme_helper.ex`) provides `color/1`
- **Themes**: Standard (default, Catppuccin Mocha), Daylight, Cyberdeck, Fifth Element
- Theme is stored in encrypted settings (`Worth.Settings`) and resolved via `Worth.Theme.Registry`

### UI Development Rules

1. **NEVER use hardcoded color classes** (e.g., `text-ctp-blue`, `bg-ctp-mantle`)
2. **ALWAYS use theme colors** via the `color(:key)` helper
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

1. Create `lib/worth/theme/my_theme.ex` implementing the `Worth.Theme` behaviour
2. Define all color keys in `colors/0`
3. Add custom CSS in `css/0` if needed
4. Register in `lib/worth/theme/registry.ex`

## Documentation

Design docs live in `docs/` — start with `vision.md`, `architecture.md`, `brain.md`, `memory.md`, `skills.md`, `mcp.md` for the big picture. `implementation-strategy.md` describes the 7-phase build plan, and `llm-provider-abstraction-plan.md` records the LLM layer's migration history.
