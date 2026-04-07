# Risks & Mitigations

| Risk | Impact | Mitigation |
|------|--------|------------|
| TermUI is new (181 stars, 0.2.0) | API instability, missing features | Pin version, fork if needed; Elm Architecture is simple to replicate |
| PostgreSQL dependency for local CLI | Setup friction | Document setup clearly; provide local JSONL fallback for zero-dependency mode |
| AgentEx callback surface is large | Integration complexity | Start minimal (only `:llm_chat` + `:on_event`), add incrementally |
| Context window management | Quality degradation on long sessions | AgentEx ContextGuard handles compaction; worth adds UI feedback |
| Streaming latency in terminal | Perceived slowness | TermUI renders at 60fps; batch small chunks (50ms window) |
| MCP server reliability | External dependency failures | ConnectionMonitor with health checks + backoff; graceful degradation |
| MCP tool name collisions | Ambiguous tool calls | Namespace with `server_name:tool_name` prefix |
| Self-evolving skill quality | Degradation over time | Trust levels + human promotion gate; version rollback; A/B testing |
| Global memory noise | Irrelevant cross-workspace context | Workspace relevance boosting; outcome feedback; memory decay |
| Security of learned skills | Malicious skill content | Learned skills start restricted; sandboxed testing; human review gate |
| PubSub message storms | UI overwhelmed by events | Topic isolation; debounce rendering at 50ms windows; backpressure via selective subscribe |
