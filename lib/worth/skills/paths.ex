defmodule Worth.Skill.Paths do
  @moduledoc """
  Shared skill path resolution. Single source of truth for locating
  skill directories.

  Core skills are bundled in `priv/core_skills/` (read-only).
  User and learned skills live inside each workspace at
  `<workspace>/.worth/skills/` and `<workspace>/.worth/skills/learned/`.
  """

  def core_dir, do: Path.join(:code.priv_dir(:worth), "core_skills")

  @doc "User-installed skills directory for a workspace."
  def user_dir(workspace) do
    Path.join(Worth.Workspace.Service.resolve_path(workspace), ".worth/skills")
  end

  @doc "Agent-learned skills directory for a workspace."
  def learned_dir(workspace) do
    Path.join(user_dir(workspace), "learned")
  end

  @doc """
  Resolves a skill name to its directory path.
  Checks core first, then workspace-local (user, learned) directories.
  If no workspace is given, searches all workspaces.
  Returns nil if not found.
  """
  def resolve(skill_name, workspace \\ nil) do
    core_path = Path.join(core_dir(), skill_name)

    if File.dir?(core_path) do
      core_path
    else
      workspaces = if workspace, do: [workspace], else: Worth.Workspace.Service.list()

      Enum.find_value(workspaces, fn ws ->
        candidates = [
          Path.join(user_dir(ws), skill_name),
          Path.join(learned_dir(ws), skill_name)
        ]

        Enum.find(candidates, &File.dir?/1)
      end)
    end
  end

  @doc """
  Returns true if the skill lives in the core skills directory.
  """
  def core?(skill_name) do
    File.dir?(Path.join(core_dir(), skill_name))
  end
end
