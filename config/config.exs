import Config

config :worth,
  llm: [
    default_provider: :anthropic,
    providers: %{
      anthropic: [
        api_key: {:env, "ANTHROPIC_API_KEY"},
        default_model: "claude-sonnet-4-20250514"
      ]
    }
  ],
  memory: [
    enabled: true,
    extraction: :llm,
    auto_flush: true,
    decay_days: 90
  ],
  workspaces: [
    default: "personal",
    directory: "~/.worth/workspaces"
  ],
  ui: [
    theme: :dark,
    sidebar: :auto
  ],
  cost_limit: 5.0,
  max_turns: 50

config :worth, Worth.Repo,
  username: "postgres",
  password: "postgres",
  database: "worth_dev",
  hostname: "localhost",
  port: 5432,
  stacktrace: true,
  show_sensitive_data_on_connection_error: true,
  pool_size: 10

config :mneme,
  repo: Worth.Repo,
  embedding: [
    provider: Mneme.Embedding.Mock,
    mock: true
  ]

import_config "#{config_env()}.exs"
