defmodule Worth.Brain do
  use GenServer

  defstruct [
    :ui_pid,
    :current_workspace,
    :workspace_path,
    :session_id,
    :history,
    :config,
    :cost_total,
    :status,
    :mode,
    :profile,
    :tool_permissions,
    :pending_approval,
    :active_tools
  ]

  @default_tool_permissions %{
    "bash" => :approve,
    "write_file" => :approve,
    "edit_file" => :auto,
    "read_file" => :auto,
    "list_files" => :auto,
    "skill_list" => :auto,
    "skill_read" => :auto,
    "memory_query" => :auto,
    "memory_write" => :auto,
    "memory_note" => :auto,
    "memory_recall" => :auto,
    "search_tools" => :auto,
    "use_tool" => :auto,
    "get_tool_schema" => :auto,
    "activate_tool" => :auto,
    "deactivate_tool" => :auto
  }

  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  def send_message(text) do
    GenServer.call(__MODULE__, {:send_message, text}, :infinity)
  end

  def set_ui_pid(pid) do
    GenServer.call(__MODULE__, {:set_ui_pid, pid})
  end

  def get_status do
    GenServer.call(__MODULE__, :get_status)
  end

  def approve_tool(tool_call_id) do
    GenServer.call(__MODULE__, {:approve_tool, tool_call_id})
  end

  def deny_tool(tool_call_id) do
    GenServer.call(__MODULE__, {:deny_tool, tool_call_id})
  end

  def switch_mode(mode) do
    GenServer.call(__MODULE__, {:switch_mode, mode})
  end

  def switch_workspace(name) do
    GenServer.call(__MODULE__, {:switch_workspace, name})
  end

  @impl true
  def init(opts) do
    workspace = Keyword.get(opts, :workspace, "personal")
    mode = Keyword.get(opts, :mode, :code)

    state = %__MODULE__{
      ui_pid: Keyword.get(opts, :ui_pid),
      current_workspace: workspace,
      workspace_path:
        Keyword.get(opts, :workspace_path) ||
          Path.expand("~/.worth/workspaces/#{workspace}"),
      session_id: generate_session_id(),
      history: [],
      config: Worth.Config.get_all(),
      cost_total: 0.0,
      status: :idle,
      mode: mode,
      profile: mode_to_profile(mode),
      tool_permissions: @default_tool_permissions,
      pending_approval: nil,
      active_tools: []
    }

    {:ok, state}
  end

  @impl true
  def handle_call({:set_ui_pid, pid}, _from, state) do
    {:reply, :ok, %{state | ui_pid: pid}}
  end

  def handle_call(:get_status, _from, state) do
    status = %{
      status: state.status,
      cost: state.cost_total,
      workspace: state.current_workspace,
      mode: state.mode,
      profile: state.profile,
      session_id: state.session_id,
      active_tools: state.active_tools
    }

    {:reply, status, state}
  end

  def handle_call({:send_message, text}, from, state) do
    Task.Supervisor.start_child(Worth.TaskSupervisor, fn ->
      result = execute_agent_loop(text, state)
      GenServer.reply(from, result)
    end)

    {:noreply, %{state | status: :running}}
  end

  def handle_call({:approve_tool, _tool_call_id}, _from, state) do
    {:reply, :ok, state}
  end

  def handle_call({:deny_tool, _tool_call_id}, _from, state) do
    {:reply, :denied, state}
  end

  def handle_call({:switch_mode, mode}, _from, state) do
    {:reply, :ok, %{state | mode: mode, profile: mode_to_profile(mode)}}
  end

  def handle_call({:switch_workspace, name}, _from, state) do
    path = Worth.Workspace.Service.resolve_path(name)
    new_state = %{state | current_workspace: name, workspace_path: path, history: [], session_id: generate_session_id()}
    {:reply, :ok, new_state}
  end

  @impl true
  def handle_info({:agent_event, event}, state) do
    if state.ui_pid do
      send(state.ui_pid, {:agent_event, event})
    end

    state =
      case event do
        {:cost, amount} ->
          %{state | cost_total: state.cost_total + amount}

        {:status, status} ->
          %{state | status: status}

        {:done, %{cost: cost}} ->
          %{state | status: :idle, cost_total: state.cost_total + (cost || 0.0)}

        {:tool_call, %{name: name}} ->
          %{state | active_tools: state.active_tools ++ [name]}

        _ ->
          state
      end

    {:noreply, state}
  end

  defp execute_agent_loop(text, state) do
    callbacks = build_callbacks(state)

    workspace_path =
      state.workspace_path ||
        Path.expand("~/.worth/workspaces/#{state.current_workspace}")

    try do
      system_prompt =
        case Worth.Workspace.Context.build_system_prompt(workspace_path) do
          {:ok, prompt} -> prompt
          {:error, _} -> nil
        end

      run_opts = [
        prompt: text,
        workspace: workspace_path,
        callbacks: callbacks,
        profile: state.profile,
        mode: mode_to_agent_mode(state.mode),
        session_id: state.session_id,
        caller: self(),
        cost_limit: state.config[:cost_limit] || 5.0,
        history: state.history,
        tool_permissions: state.tool_permissions
      ]

      run_opts = if system_prompt, do: Keyword.put(run_opts, :system_prompt, system_prompt), else: run_opts

      result = AgentEx.run(run_opts)

      case result do
        {:ok, response} ->
          {:ok, response}

        {:error, reason} ->
          {:error, reason}
      end
    rescue
      e ->
        {:error, Exception.message(e)}
    end
  end

  defp build_callbacks(state) do
    ui_pid = state.ui_pid

    %{
      llm_chat: fn params ->
        Worth.LLM.chat(params, state.config)
      end,
      on_event: fn event, _ctx ->
        send(self(), {:agent_event, event})
        if ui_pid, do: send(ui_pid, {:agent_event, event})
        :ok
      end,
      on_tool_approval: fn name, input, _ctx ->
        if ui_pid do
          send(ui_pid, {:agent_event, {:tool_approval_request, name, input}})
        end

        :approved
      end,
      knowledge_search: fn query, opts ->
        if Worth.Config.get([:memory, :enabled], true) do
          Mneme.search(query, Keyword.put(opts, :scope_id, "worth"))
        else
          {:ok, %{entries: [], chunks: [], entities: []}}
        end
      end,
      knowledge_create: fn params ->
        if Worth.Config.get([:memory, :enabled], true) do
          Mneme.remember(params[:content] || params.content, %{
            scope_id: "worth",
            content: params[:content] || params.content,
            entry_type: params[:entry_type] || "fact",
            metadata: Map.put(params[:metadata] || %{}, :workspace, state.workspace_path)
          })
        else
          {:ok, nil}
        end
      end,
      knowledge_recent: fn _scope_id ->
        if Worth.Config.get([:memory, :enabled], true) do
          Mneme.Knowledge.recent("worth")
        else
          {:ok, []}
        end
      end,
      on_persist_turn: fn ctx, text ->
        Worth.Persistence.Transcript.append(
          ctx.session_id || state.session_id,
          %{role: "assistant", text: text},
          state.workspace_path
        )

        :ok
      end,
      on_response_facts: fn _ctx, _text ->
        :ok
      end,
      on_tool_facts: fn _ws_id, _name, _result, _turn ->
        :ok
      end,
      search_tools: fn _query, _opts ->
        []
      end,
      execute_external_tool: fn name, args, _ctx ->
        {:error, "External tool '#{name}' not configured"}
      end,
      get_tool_schema: fn _name ->
        {:error, :not_found}
      end
    }
  end

  defp mode_to_profile(:code), do: :agentic
  defp mode_to_profile(:research), do: :conversational
  defp mode_to_profile(_), do: :agentic

  defp mode_to_agent_mode(:code), do: :agentic
  defp mode_to_agent_mode(:research), do: :conversational
  defp mode_to_agent_mode(:planned), do: :agentic_planned
  defp mode_to_agent_mode(:turn_by_turn), do: :turn_by_turn
  defp mode_to_agent_mode(_), do: :agentic

  defp generate_session_id do
    "worth-#{:rand.uniform(1_000_000) |> Integer.to_string() |> String.pad_leading(6, "0")}"
  end
end
