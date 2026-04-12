defmodule Worth.Boot do
  @moduledoc """
  Starts the Worth application and returns the URL.
  Used by both CLI and desktop bridge.
  """

  def run(opts \\ []) do
    Worth.Config.Setup.maybe_run_first_run!()
    ensure_directories!()

    workspace = Keyword.get(opts, :workspace, "personal")
    mode = parse_mode(Keyword.get(opts, :mode, "code"))

    workspace_path = Worth.Workspace.Service.resolve_path(workspace)

    if !File.dir?(workspace_path) do
      IO.puts("Workspace '#{workspace}' not found. Creating...")
      Worth.Workspace.Service.create(workspace)
    end

    Application.put_env(:worth, :current_workspace, workspace)
    Application.put_env(:worth, :current_workspace_path, workspace_path)
    Application.put_env(:worth, :current_mode, mode)

    if auto_migrate?() do
      run_migrations!()
    end

    Worth.Brain.ensure(workspace)
    Worth.Brain.switch_mode(workspace, mode)

    url()
  end

  def url do
    endpoint_config = Application.get_env(:worth, WorthWeb.Endpoint)
    port = get_in(endpoint_config, [:http, :port]) || 4090
    "http://localhost:#{port}"
  end

  def auto_migrate? do
    System.get_env("WORTH_DESKTOP") == "1" or
      System.get_env("WORTH_AUTO_MIGRATE") == "1"
  end

  def run_migrations! do
    if Worth.Repo.libsql?() do
      db_path = Application.get_env(:worth, Worth.Repo)[:database]

      if db_path do
        db_path |> Path.dirname() |> File.mkdir_p!()
      end

      Ecto.Migrator.run(Worth.Repo, :up, all: true)
    end
  rescue
    e ->
      IO.warn("Migration failed: #{inspect(e)}")
  end

  defp parse_mode("code"), do: :code
  defp parse_mode("research"), do: :research
  defp parse_mode("planned"), do: :planned
  defp parse_mode("turn_by_turn"), do: :turn_by_turn
  defp parse_mode(_), do: :code

  defp ensure_directories! do
    Worth.Paths.ensure_data_dir!()
    Worth.Paths.ensure_workspace_dir!()
  end
end
