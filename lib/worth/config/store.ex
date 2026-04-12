defmodule Worth.Config.Store do
  @moduledoc """
  On-disk persistence for Worth's user-level config.

  The config file lives inside the data directory (OS-conventional,
  auto-detected by `Worth.Paths.data_dir/0`). The file is a single
  Elixir map literal evaluated with `Code.eval_file/1`.

  This module is the only place that touches the file. Higher-level callers
  go through `Worth.Config` (in-memory) and `Worth.Config.Setup` (mutations).
  """

  @doc "Absolute path to the config file inside the data directory."
  def path do
    Path.join(Worth.Paths.data_dir(), "config.exs")
  end

  @doc "True if the config file exists on disk."
  def exists? do
    File.exists?(path())
  end

  @doc """
  Loads the on-disk config map. Creates the file with defaults if it doesn't
  exist. Returns an empty map if the file fails to parse.
  """
  def load do
    file = path()

    cond do
      not File.exists?(file) ->
        # Initialize with empty config - defaults come from Application env
        ensure_config_dir!()
        save!(%{})
        %{}

      true ->
        try do
          {value, _} = Code.eval_file(file)
          if is_map(value), do: value, else: %{}
        rescue
          e ->
            require Logger
            Logger.warning("Worth.Config.Store: failed to load #{file}: #{Exception.message(e)}")
            %{}
        end
    end
  end

  defp ensure_config_dir! do
    path() |> Path.dirname() |> File.mkdir_p!()
  end

  @doc """
  Persists `map` to disk, creating parent directories as needed and
  forcing `0600` perms on the file.
  """
  def save!(map) when is_map(map) do
    file = path()
    File.mkdir_p!(Path.dirname(file))
    File.write!(file, format(map))
    _ = File.chmod(file, 0o600)
    :ok
  end

  defp format(map) do
    """
    # Worth config — managed by Worth.Config.Store.
    # Hand edits are preserved on the next save as long as the file
    # remains a single Elixir map literal. Secrets are plain text;
    # keep this file at 0600.
    #{inspect(map, pretty: true, limit: :infinity, printable_limit: :infinity)}
    """
  end
end
