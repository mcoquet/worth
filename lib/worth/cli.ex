defmodule Worth.CLI do
  def main(args \\ []) do
    {opts, _rest} =
      OptionParser.parse!(args,
        strict: [
          workspace: :string,
          mode: :string,
          help: :boolean,
          version: :boolean,
          init: :string
        ],
        aliases: [
          w: :workspace,
          m: :mode,
          h: :help,
          v: :version
        ]
      )

    cond do
      opts[:help] ->
        print_help()

      opts[:version] ->
        IO.puts("worth v0.1.0")

      opts[:init] ->
        init_workspace(opts[:init])

      true ->
        start_worth(opts)
    end
  end

  defp start_worth(opts) do
    workspace = opts[:workspace] || "personal"
    mode = parse_mode(opts[:mode] || "code")
    workspace_path = Path.expand("~/.worth/workspaces/#{workspace}")

    unless File.dir?(workspace_path) do
      IO.puts("Workspace '#{workspace}' not found. Creating...")
      Worth.Workspace.Service.create(workspace, type: mode_to_type(mode))
    end

    Application.put_env(:worth, :current_workspace, workspace)
    Application.put_env(:worth, :current_workspace_path, workspace_path)
    Application.put_env(:worth, :current_mode, mode)

    TermUI.Runtime.run(root: Worth.UI.Root, workspace: workspace, mode: mode)
  end

  defp init_workspace(name) do
    case Worth.Workspace.Service.create(name) do
      {:ok, path} ->
        IO.puts("Created workspace '#{name}' at #{path}")

      {:error, reason} ->
        IO.puts("Error: #{reason}")
    end
  end

  defp parse_mode("code"), do: :code
  defp parse_mode("research"), do: :research
  defp parse_mode("planned"), do: :planned
  defp parse_mode("turn_by_turn"), do: :turn_by_turn
  defp parse_mode(_), do: :code

  defp mode_to_type(:research), do: :research
  defp mode_to_type(_), do: :code

  defp print_help do
    IO.puts("""
    worth v0.1.0 - A terminal-based AI assistant

    Usage:
      worth [options]

    Options:
      -w, --workspace <name>   Open a specific workspace (default: personal)
      -m, --mode <mode>        Execution mode: code | research | planned | turn_by_turn
      --init <name>            Create a new workspace and exit
      -h, --help               Show this help message
      -v, --version            Show version

    Commands (inside worth):
      /help              Show available commands
      /quit              Exit worth
      /clear             Clear chat history
      /cost              Show session cost
      /status            Show current status
      /mode <mode>       Switch execution mode
      /workspace list    List workspaces
      /workspace new <n> Create workspace
      /workspace switch  Switch workspace

    Keyboard:
      Tab                Toggle sidebar
      Up/Down            Command history
    """)
  end
end
