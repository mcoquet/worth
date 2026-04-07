# UI Design (TermUI)

## Layout

```
┌──────────────────────────────────────────────────────────┐
│  worth ▸ my-project                      [mode: code]   │
├────────────────────────────────────┬─────────────────────┤
│                                    │  Workspace          │
│  Chat                              │  ┌───────────────┐  │
│                                    │  │ IDENTITY.md   │  │
│  > help me refactor the auth       │  │ AGENTS.md     │  │
│    module                          │  │ skills/       │  │
│                                    │  └───────────────┘  │
│  I'll start by reading the current │                     │
│  auth module to understand the     │  Tools (active)     │
│  structure...                      │  ┌───────────────┐  │
│                                    │  │ read_file     │  │
│  ┌ read_file: lib/auth.ex ────────┐│  │ write_file    │  │
│  │  defmodule MyApp.Auth do       ││  │ edit_file     │  │
│  │    def authenticate(user) do   ││  │ bash          │  │
│  │      ...                       ││  │ list_files    │  │
│  └────────────────────────────────┘│  │ memory_query  │  │
│                                    │  └───────────────┘  │
│  Now I'll refactor the module to   │                     │
│  extract the token validation...   │  Status             │
│                                    │  Cost: $0.042      │
│  ┌ edit_file: lib/auth.ex ────────┐│  Turns: 5/50       │
│  │  ✓ Applied 3 edits             │  Model: claude-4   │
│  └────────────────────────────────┘│                     │
│                                    │                     │
├────────────────────────────────────┴─────────────────────┤
│  > type a message... /help for commands                  │
└──────────────────────────────────────────────────────────┘
```

## Elm Architecture

```
Worth.UI.Root
├── Worth.UI.Header          (workspace name, mode indicator, status)
├── Worth.UI.Body (SplitPane)
│   ├── Worth.UI.Chat        (main conversation, scrollable Viewport)
│   │   ├── MessageBlock     (assistant text, markdown rendered)
│   │   ├── ToolCallBlock    (collapsible tool call + result)
│   │   └── ThinkingBlock    (optional: streaming thinking tokens)
│   └── Worth.UI.Sidebar (Tabs)
│       ├── WorkspaceTab     (file tree, identity files)
│       ├── ToolsTab         (active tools, tool history)
│       ├── SkillsTab        (installed + learned skills with trust badges)
│       └── StatusTab        (cost, tokens, model, plan progress, MCP status)
└── Worth.UI.Input           (TextInput, command palette with /)
```

## Key UI Components

| Component | TermUI Widget | Behavior |
|-----------|--------------|----------|
| Chat area | `Viewport` | Auto-scroll, virtual scrolling |
| Input | `TextInput` | Single-line, history (up arrow), `/` command prefix |
| Sidebar | `Tabs` | Switchable panels |
| File tree | `TreeView` | Workspace file listing |
| Tool trace | `Collapsible` in Viewport | Expandable tool call/result blocks |
| Status bar | `Gauge` + `Text` | Cost tracking, turn counter, model name |
| Command palette | `CommandPalette` | Fuzzy search over `/` commands |
| Toast | `Toast` | Non-blocking notifications |
| Progress | `Gauge` | Plan step completion |

## Event Flow

```
User types message
    │
    ▼
Worth.UI.Input → {:msg, {:user_input, text}}
    │
    ▼
Worth.UI.Root.update/2 → Worth.Brain.send_message(text)
    │
    ▼
Worth.Brain (GenServer) → AgentEx.run/1
    │
    │  AgentEx emits events via :on_event callback:
    │  - {:text_chunk, "I'll read..."}
    │  - {:tool_call, %{name: "read_file", input: %{...}}}
    │  - {:tool_result, %{name: "read_file", output: "..."}}
    │  - {:status, :idle | :running | :error}
    │  - {:cost, 0.042}
    │  - {:done, %{text: "...", cost: 0.042, tokens: %{...}}}
    │
    ▼
Brain sends cast to UI process: Worth.UI.Root.handle_agent_event(event)
    │
    ▼
UI updates state, TermUI re-renders differential
```

Communication:
- **UI → Brain**: `GenServer.call(Worth.Brain, {:send_message, text})` (synchronous)
- **Brain → UI**: `send(ui_pid, {:agent_event, event})` (async streaming)

## Slash Commands

| Command | Action |
|---------|--------|
| `/help` | Show available commands |
| `/mode code\|research\|planned\|turn-by-turn` | Switch execution mode |
| `/workspace list` | List all workspaces |
| `/workspace switch <name>` | Switch workspace |
| `/workspace new <name>` | Create new workspace |
| `/model <name>` | Change LLM model |
| `/skill list` | List installed and learned skills |
| `/skill install <owner/repo>` | Install skill from GitHub |
| `/skill read <name>` | Read skill content |
| `/skill remove <name>` | Remove skill |
| `/skill review <name>` | Review and promote/demote |
| `/skill revert <name> [version]` | Roll back skill version |
| `/skill export <name>` | Export skill as archive |
| `/kit search <query>` | Search JourneyKits for workflows |
| `/kit install <owner/slug>` | Install a kit |
| `/kit list` | List installed kits |
| `/kit info <owner/slug>` | Show kit details |
| `/kit publish <dir>` | Publish a kit from directory |
| `/memory query <text>` | Search knowledge store |
| `/memory note <text>` | Store a note in working memory |
| `/clear` | Clear chat history |
| `/cost` | Show session cost summary |
| `/compact` | Force context compaction |
| `/mcp list` | List MCP servers |
| `/mcp add <name>` | Add MCP server |
| `/mcp remove <name>` | Remove MCP server |
| `/mcp connect <name>` | Connect MCP server |
| `/mcp disconnect <name>` | Disconnect MCP server |
| `/mcp tools <name>` | List MCP server tools |
| `/mcp status <name>` | MCP server status |
| `/quit` | Exit worth |
