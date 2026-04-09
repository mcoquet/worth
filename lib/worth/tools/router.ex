defmodule Worth.Tools.Router do
  @moduledoc """
  Routes tool calls to the appropriate Worth tool module based on name prefix.
  Single source of truth for tool definition aggregation and dispatch.
  """

  @tool_modules [
    {"memory_", Worth.Tools.Memory},
    {"skill_", Worth.Tools.Skills},
    {"mcp_", Worth.Tools.Mcp},
    {"kit_", Worth.Tools.Kits}
  ]

  def all_definitions do
    Enum.flat_map(@tool_modules, fn {_prefix, mod} -> mod.definitions() end)
  end

  def execute(name, args, workspace) do
    case find_module(name) do
      {:ok, mod} ->
        mod.execute(name, args, workspace)

      :not_found ->
        if String.contains?(name, ":") do
          Worth.Mcp.Gateway.execute(name, args)
        else
          {:error, "External tool '#{name}' not configured"}
        end
    end
  end

  def get_schema(name) do
    Enum.find(all_definitions(), fn d ->
      (d[:name] || d["name"]) == name
    end)
  end

  defp find_module(name) do
    case Enum.find(@tool_modules, fn {prefix, _} -> String.starts_with?(name, prefix) end) do
      {_, mod} -> {:ok, mod}
      nil -> :not_found
    end
  end
end
