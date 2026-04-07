defmodule Worth.Workspace.Context do
  @system_prompt_path Path.join(:code.priv_dir(:worth), "prompts/system.md")

  def build_system_prompt(workspace_path, opts \\ []) do
    base = load_base_prompt()
    identity = load_identity(workspace_path)
    agents = load_agents(workspace_path)

    parts =
      [base, identity, agents]
      |> Enum.reject(&is_nil/1)
      |> Enum.reject(&(&1 == ""))
      |> Enum.join("\n\n")

    {:ok, parts}
  end

  defp load_base_prompt do
    case File.read(@system_prompt_path) do
      {:ok, content} -> String.trim(content)
      {:error, _} -> "You are worth, a terminal-based AI assistant."
    end
  end

  defp load_identity(workspace_path) do
    case File.read(Path.join(workspace_path, "IDENTITY.md")) do
      {:ok, content} -> String.trim(content)
      {:error, _} -> nil
    end
  end

  defp load_agents(workspace_path) do
    case File.read(Path.join(workspace_path, "AGENTS.md")) do
      {:ok, content} -> String.trim(content)
      {:error, _} -> nil
    end
  end
end
