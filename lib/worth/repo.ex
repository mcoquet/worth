defmodule Worth.Repo do
  @moduledoc """
  Ecto Repository for Worth.

  Uses SQLite3 with sqlite-vec extension for vector search.
  """

  use Ecto.Repo,
    otp_app: :worth,
    adapter: Ecto.Adapters.SQLite3

  @impl true
  def init(_type, config) do
    # Load sqlite-vec extension at runtime (can't be done in compile-time config)
    extensions = if Code.ensure_loaded?(SqliteVec), do: [SqliteVec.path()], else: []
    config = Keyword.update(config, :load_extensions, extensions, &(extensions ++ &1))
    {:ok, config}
  end

  @doc """
  Returns the installed extensions.
  sqlite-vec is loaded at runtime via load_extensions config.
  """
  def installed_extensions, do: []

  @doc "Returns the configured database adapter."
  def adapter, do: Ecto.Adapters.SQLite3
end
