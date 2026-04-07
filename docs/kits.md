# Kits (JourneyKits Integration)

## Concept

[Jump to Conclusion](#how-it-fits-worth) if you want the summary first.

## What JourneyKits Is

JourneyKits is a registry for packaged AI agent workflows. Think npm for agent workflows. A **kit** bundles:

- Multiple **skills** (SKILL.md files)
- **Source code** (tested scripts, configs, patches)
- **Tool docs** and **setup instructions**
- **Examples** and **assets**
- Structured **metadata** (models, parameters, failures, verification)

The format is `kit.md` — YAML frontmatter + markdown body, similar to SKILL.md but much richer.

## Kit vs Skill

| Aspect | Skill (agentskills.io) | Kit (journeykits) |
|--------|----------------------|-------------------|
| Granularity | Single capability (e.g., "git workflow") | Complete workflow (e.g., "deploy a Phoenix app to Fly.io") |
| Format | SKILL.md (frontmatter + markdown) | kit.md (frontmatter + markdown) + bundle directory |
| Contents | Instructions only | Skills + source code + config + examples + tool docs |
| Composition | One file | Multiple skills, scripts, and assets |
| Scope | How to do one thing | How to accomplish an entire task end-to-end |
| Registry | None (local or GitHub) | JourneyKits API (search, install, publish) |
| Verification | Worth's trust levels + A/B testing | JourneyKits safety scan + community learnings |

A kit is a superset of a skill. A kit can contain skills. Worth's skill system handles individual capabilities; kits are **composed workflows**.

## Kit Format (kit.md v1.0)

```yaml
---
schema: kit/1.0
slug: phoenix-deploy-flyio
title: Deploy Phoenix App to Fly.io
summary: >
  Complete workflow for deploying a Phoenix LiveView app to Fly.io
  with PostgreSQL, health checks, and release commands.
version: 1.2.0
license: MIT
tags: [elixir, phoenix, deployment, flyio]

model:
  provider: anthropic
  name: claude-sonnet-4-20250514
  hosting: "cloud API — requires ANTHROPIC_API_KEY"

tools: [terminal, flyctl, git]
skills: [phoenix-conventions, flyio-deploy]
tech: [elixir, phoenix, postgres, flyio]

services:
  - name: Fly.io
    role: hosting platform
    version: "latest"
  - name: PostgreSQL
    role: database
    version: "16"

parameters:
  - name: region
    value: "lax"
    description: Fly.io region for deployment

failures:
  - problem: Release command hangs on first deploy
    resolution: Set `RELEASE_COMMAND` to `/app/bin/migrate` and add health check timeout

prerequisites:
  - name: flyctl
    check: "flyctl version"
  - name: Elixir
    check: "elixir --version"

fileManifest:
  - path: fly.toml
    role: config
    description: Fly.io app configuration
  - path: Dockerfile
    role: build
    description: Multi-stage build for Phoenix

selfContained: true
---

## Goal

Deploy a Phoenix LiveView application to Fly.io with a provisioned
PostgreSQL database, health checks, and automatic migrations on deploy.

## When to Use

Use this kit when deploying a new Phoenix app or migrating an existing
one to Fly.io. Works with Elixir 1.15+ and Phoenix 1.7+.

## Steps

1. Install flyctl and authenticate
2. Create a Fly.io app with the correct region
3. Provision a PostgreSQL database (Fly Postgres)
4. Configure the Dockerfile for Phoenix
5. Set up release commands for migrations
6. Configure health check endpoints
7. Deploy and verify

## Constraints

- Phoenix 1.7+ required for default health check endpoint
- Fly.io free tier has limited resources (256MB RAM)

## Safety Notes

- Do not commit FLY_API_TOKEN to the repository
- Database credentials are injected via Fly.io secrets, not env files
```

Bundle layout:
```
phoenix-deploy-flyio/
├── kit.md              # Required
├── skills/             # Skills used in this workflow
│   ├── phoenix-conventions/
│   │   └── SKILL.md
│   └── flyio-deploy/
│       └── SKILL.md
├── src/                # Tested source files
│   ├── fly.toml
│   └── Dockerfile
└── examples/
    └── deploy-log.txt
```

## JourneyKits API

JourneyKits provides a REST API at `https://journeykits.ai/api/`. No MCP server exists yet.

Key endpoints for worth:

| Endpoint | Purpose | Auth |
|----------|---------|------|
| `GET /api/kits/search?q=...` | Search for kits by query | None |
| `GET /api/kits/{owner}/{slug}` | Get kit details | None |
| `GET /api/kits/{owner}/{slug}/install` | Install a kit (returns files + instructions) | None |
| `POST /api/kits/{owner}/{slug}/preflight` | Check if kit can run in current environment | API key |
| `POST /api/kits/{owner}/{slug}/outcome` | Report success/failure after using a kit | Scoped token |
| `POST /api/kits/import` | Publish a new kit | `kits:write` |
| `POST /api/kits/{owner}/{slug}/releases` | Create a release | `kits:write` |
| `GET /api/kits/publish-to-journey` | Get instructions for publishing | None |

Installation flow:
1. Agent searches for relevant kit
2. Fetches install payload (files + instructions)
3. Extracts skills into `~/.worth/skills/`
4. Writes source files to workspace
5. Runs preflight checks
6. Follows the kit's Steps section

## How It Fits Worth

### Three integration points:

**1. Kit Consumption** (agent discovers and installs kits)

The agent can search JourneyKits when facing a novel task:

```
User: "Help me deploy this Phoenix app to Fly.io"
  → Agent searches JourneyKits for "phoenix deploy flyio"
  → Finds kit: phoenix-deploy-flyio v1.2.0
  → Fetches install payload
  → Installs bundled skills into ~/.worth/skills/
  → Follows the kit's Steps to complete the task
```

**2. Kit Publishing** (worth exports proven workflows as kits)

After successfully completing a complex task, worth can package the approach as a kit:

```
Agent completed: "Set up CI/CD with GitHub Actions for Elixir project"
  → Agent packages:
    - Learned skills (e.g., "elixir-ci-conventions")
    - Source files (.github/workflows/ci.yml)
    - Failure lessons (what went wrong, how it was fixed)
  → Publishes as kit to JourneyKits
  → Other agents can now reuse this workflow
```

**3. Kit as Workspace Template** (kit scaffolds a complete workspace)

Instead of just skills, a kit can scaffold an entire workspace:

```
worth init my-phoenix-app --kit phoenix-deploy-flyio
  → Creates workspace directory
  → Installs kit skills into ~/.worth/skills/
  → Writes kit source files to workspace
  → Sets up .worth/skills.json with kit's active skills
  → Configures workspace identity from kit metadata
```

## Implementation

### Module: Worth.Kits

```elixir
defmodule Worth.Kits do
  @base_url "https://journeykits.ai/api"

  def search(query, opts \\ []) do
    # GET /api/kits/search?q=...&tag[]=...&tech[]=...
  end

  def install(owner, slug, opts \\ []) do
    # GET /api/kits/{owner}/{slug}/install
    # 1. Fetch install payload
    # 2. Extract skills into ~/.worth/skills/
    # 3. Write src/ files to workspace
    # 4. Update .worth/skills.json
    # 5. Run preflight checks
  end

  def publish(kit_dir, opts \\ []) do
    # POST /api/kits/import
    # Package local skills + source into kit.md bundle
  end

  def preflight(owner, slug) do
    # POST /api/kits/{owner}/{slug}/preflight
  end

  def report_outcome(owner, slug, outcome, tracking_token) do
    # POST /api/kits/{owner}/{slug}/outcome
  end
end
```

### Kit Tools

| Tool | Purpose | Who |
|------|---------|-----|
| `kit_search` | Search JourneyKits for workflows | Agent + user |
| `kit_install` | Install a kit (skills + files) | Agent + user |
| `kit_list` | List installed kits | Agent + user |
| `kit_publish` | Package and publish a workflow as a kit | User |
| `kit_info` | Get kit details and dependencies | Agent |

### Slash Commands

| Command | Action |
|---------|--------|
| `/kit search <query>` | Search JourneyKits |
| `/kit install <owner/slug>` | Install a kit |
| `/kit list` | List installed kits |
| `/kit publish <dir>` | Publish a kit from a directory |
| `/kit info <owner/slug>` | Show kit details |

### Kit-to-Skill Mapping

When installing a kit, skills are extracted into the global skills directory with kit provenance:

```elixir
# Kit skill gets installed with provenance tracking
%{
  name: "flyio-deploy",
  trust_level: :installed,       # not :core, not :learned
  provenance: :kit,              # new provenance type
  kit: %{
    slug: "phoenix-deploy-flyio",
    owner: "worth-community",
    version: "1.2.0"
  }
}
```

### Kit State Tracking

Installed kits tracked in global config:

```elixir
# ~/.worth/config.exs
config :worth,
  kits: [
    installed: %{
      "worth-community/phoenix-deploy-flyio" => %{
        version: "1.2.0",
        installed_at: "2026-04-07T10:00:00Z",
        skills: ["phoenix-conventions", "flyio-deploy"],
        status: :active
      }
    }
  ]
```

### Config

```elixir
config :worth,
  kits: [
    registry_url: "https://journeykits.ai/api",
    auto_update: false,
    agent_id: nil,              # for publishing
    api_key: {:env, "JOURNEY_API_KEY"}
  ]
```

## Relationship to Existing Systems

```
JourneyKits (external registry)
    │
    │  install
    ▼
Worth.Kits ──► extracts skills ──► ~/.worth/skills/ (global)
           ──► writes src/    ──► workspace directory
           ──► updates        ──► .worth/skills.json
    │
    │  uses
    ▼
Worth.Skills (existing)
    │
    │  agent creates/refines
    ▼
Worth.Kits.publish() ──► packages ──► JourneyKits (external registry)
```

Kits flow through the existing skill system. They don't replace it — they compose on top of it. Skills remain the unit of agent capability. Kits are the unit of workflow packaging and sharing.

## Risks

| Risk | Mitigation |
|------|------------|
| Kit quality varies | JourneyKits has safety scanning; worth applies trust_level :installed (not :core) |
| Kit skills conflict with local skills | skills.json override mechanism handles this |
| External dependency (JourneyKits availability) | Kits are fully installed locally after fetch; no runtime dependency on the registry |
| Publishing security (api key exposure) | Key stored in env var, never in kit files; publishing requires explicit user approval |
| Kit bloat (too many skills installed) | Kit installs are tracked; `/kit list` shows what's installed; `/kit remove` cleans up |

## Phase

This integrates in **Phase 7** (Advanced Features) after the core skill system is stable. The kit consumption path (search + install) can be added earlier if desired.
