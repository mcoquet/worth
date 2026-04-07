defmodule Worth.Tools.Workspace do
  @moduledoc false

  def definitions do
    [
      %{
        "name" => "workspace_status",
        "description" => "Get current workspace information including name, path, and mode",
        "input_schema" => %{
          "type" => "object",
          "properties" => %{}
        }
      },
      %{
        "name" => "workspace_list",
        "description" => "List all available workspaces",
        "input_schema" => %{
          "type" => "object",
          "properties" => %{}
        }
      },
      %{
        "name" => "workspace_switch",
        "description" => "Switch to a different workspace",
        "input_schema" => %{
          "type" => "object",
          "properties" => %{
            "name" => %{"type" => "string", "description" => "Workspace name to switch to"}
          },
          "required" => ["name"]
        }
      }
    ]
  end

  def execute("workspace_status", _input, _ctx) do
    status = Worth.Brain.get_status()
    {:ok, "Workspace: #{status.workspace} | Mode: #{status.mode} | Profile: #{status.profile}"}
  end

  def execute("workspace_list", _input, _ctx) do
    workspaces = Worth.Workspace.Service.list()
    {:ok, "Workspaces:\n" <> Enum.map_join(workspaces, "\n", fn ws -> "  - #{ws}" end)}
  end

  def execute("workspace_switch", input, _ctx) do
    name = input["name"]
    Worth.Brain.switch_workspace(name)
    {:ok, "Switched to workspace: #{name}"}
  end
end
