defmodule Worth.Metrics.Repo do
  @moduledoc """
  Separate Ecto repository for orchestration metrics.

  Uses a dedicated SQLite database file (`metrics.db`) so metrics writes
  never contend with the main `Worth.Repo` for I/O or lock time.
  """

  use Ecto.Repo,
    otp_app: :worth,
    adapter: Ecto.Adapters.SQLite3,
    start_apps_before_migration: false
end
