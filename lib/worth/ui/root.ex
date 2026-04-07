defmodule Worth.UI.Root do
  use TermUI.Elm

  alias TermUI.{Event, Style, Command}

  @impl true
  def init(opts) do
    state = %{
      messages: [],
      input_text: "",
      status: :idle,
      cost: 0.0,
      workspace: opts[:workspace] || "personal",
      mode: opts[:mode] || :code,
      model: opts[:model] || "claude-sonnet-4",
      turn: 0,
      streaming_text: "",
      cursor_pos: 0,
      input_history: [],
      history_index: -1,
      sidebar_visible: false,
      sidebar_tab: :workspace,
      width: 80,
      height: 24
    }

    {state, [Command.interval(50, :check_events)]}
  end

  @impl true
  def event_to_msg(%Event.Key{key: :enter}, _state), do: {:msg, :submit_input}
  def event_to_msg(%Event.Key{key: :backspace}, _state), do: {:msg, :backspace}
  def event_to_msg(%Event.Key{key: :left}, _state), do: {:msg, :cursor_left}
  def event_to_msg(%Event.Key{key: :right}, _state), do: {:msg, :cursor_right}
  def event_to_msg(%Event.Key{key: :up}, _state), do: {:msg, :history_prev}
  def event_to_msg(%Event.Key{key: :down}, _state), do: {:msg, :history_next}
  def event_to_msg(%Event.Key{key: :tab}, _state), do: {:msg, :toggle_sidebar}
  def event_to_msg(%Event.Key{char: char}, _state) when is_binary(char), do: {:msg, {:type_char, char}}
  def event_to_msg(%Event.Key{key: key}, _state) when is_atom(key), do: :ignore
  def event_to_msg(%Event.Resize{width: w, height: h}, _state), do: {:msg, {:resize, w, h}}
  def event_to_msg(_, _), do: :ignore

  @impl true
  def update(:submit_input, %{input_text: ""} = state), do: {state, []}

  def update(:submit_input, state) do
    text = state.input_text

    history =
      if text != "" and (state.input_history == [] or hd(state.input_history) != text) do
        [text | state.input_history] |> Enum.take(100)
      else
        state.input_history
      end

    state = %{state | input_text: "", cursor_pos: 0, turn: state.turn + 1, input_history: history, history_index: -1}
    new_messages = state.messages ++ [{:user, text}]

    case parse_command(text) do
      {:command, :quit} ->
        {state, [Command.quit()]}

      {:command, :clear} ->
        {%{state | messages: [], streaming_text: ""}, []}

      {:command, :cost} ->
        msg = "Session cost: $#{Float.round(state.cost, 4)} | Turns: #{state.turn}"
        {%{state | messages: new_messages ++ [{:system, msg}]}, []}

      {:command, :help} ->
        help = help_text()
        {%{state | messages: new_messages ++ [{:system, help}]}, []}

      {:command, {:mode, mode}} ->
        Worth.Brain.switch_mode(mode)
        msg = "Switched to #{mode} mode"
        {%{state | messages: new_messages ++ [{:system, msg}], mode: mode}, []}

      {:command, {:workspace, :list}} ->
        workspaces = Worth.Workspace.Service.list()
        msg = "Workspaces: #{Enum.join(workspaces, ", ")}"
        {%{state | messages: new_messages ++ [{:system, msg}]}, []}

      {:command, {:workspace, {:switch, name}}} ->
        Worth.Brain.switch_workspace(name)
        msg = "Switched to workspace: #{name}"
        {%{state | messages: new_messages ++ [{:system, msg}], workspace: name}, []}

      {:command, {:workspace, {:new, name}}} ->
        case Worth.Workspace.Service.create(name) do
          {:ok, _path} ->
            Worth.Brain.switch_workspace(name)
            msg = "Created and switched to workspace: #{name}"
            {%{state | messages: new_messages ++ [{:system, msg}], workspace: name}, []}

          {:error, reason} ->
            {%{state | messages: new_messages ++ [{:error, reason}]}, []}
        end

      {:command, {:status, _}} ->
        status = Worth.Brain.get_status()

        msg =
          "Mode: #{status.mode} | Profile: #{status.profile} | Workspace: #{status.workspace} | Cost: $#{Float.round(status.cost, 3)}"

        {%{state | messages: new_messages ++ [{:system, msg}]}, []}

      {:command, {:unknown, cmd}} ->
        msg = "Unknown command: #{cmd}. Type /help for available commands."
        {%{state | messages: new_messages ++ [{:system, msg}]}, []}

      :message ->
        send_message_to_brain(text)
        {%{state | messages: new_messages, status: :running, streaming_text: ""}, []}
    end
  end

  def update(:backspace, state) do
    if state.cursor_pos > 0 do
      {before, after_c} = String.split_at(state.input_text, state.cursor_pos - 1)
      new_text = before <> String.slice(after_c, 1..-1//1)
      {%{state | input_text: new_text, cursor_pos: state.cursor_pos - 1}, []}
    else
      {state, []}
    end
  end

  def update(:cursor_left, state), do: {%{state | cursor_pos: max(state.cursor_pos - 1, 0)}, []}

  def update(:cursor_right, state) do
    {%{state | cursor_pos: min(state.cursor_pos + 1, String.length(state.input_text))}, []}
  end

  def update(:history_prev, state) do
    if state.input_history != [] do
      idx = min(state.history_index + 1, length(state.input_history) - 1)
      text = Enum.at(state.input_history, idx, "")
      {%{state | input_text: text, cursor_pos: String.length(text), history_index: idx}, []}
    else
      {state, []}
    end
  end

  def update(:history_next, state) do
    if state.history_index > 0 do
      idx = state.history_index - 1
      text = Enum.at(state.input_history, idx, "")
      {%{state | input_text: text, cursor_pos: String.length(text), history_index: idx}, []}
    else
      {%{state | input_text: "", cursor_pos: 0, history_index: -1}, []}
    end
  end

  def update(:toggle_sidebar, state) do
    {%{state | sidebar_visible: not state.sidebar_visible}, []}
  end

  def update({:type_char, char}, state) do
    {before, after_c} = String.split_at(state.input_text, state.cursor_pos)
    new_text = before <> char <> after_c
    {%{state | input_text: new_text, cursor_pos: state.cursor_pos + 1}, []}
  end

  def update({:resize, w, h}, state), do: {%{state | width: w, height: h}, []}

  def update(:check_events, state) do
    state = drain_events(state)
    {state, [Command.interval(50, :check_events)]}
  end

  def update(_, state), do: {state, []}

  @impl true
  def view(state) do
    header = render_header(state)
    chat_nodes = render_chat(state)
    input_line = render_input(state)

    if state.sidebar_visible do
      {chat_w, sidebar_w} = split_widths(state.width)

      stack(:horizontal, [
        box([header, box(chat_nodes, height: :auto), input_line], width: chat_w),
        render_sidebar(state, sidebar_w)
      ])
    else
      stack(:vertical, [header, box(chat_nodes, height: :auto), input_line])
    end
  end

  defp split_widths(total) do
    sidebar_w = min(30, div(total, 3))
    {total - sidebar_w, sidebar_w}
  end

  defp render_header(state) do
    mode_label = "[#{state.mode}]"

    indicator =
      case state.status do
        :idle -> " "
        :running -> "*"
        :error -> "!"
      end

    header_text =
      "[#{indicator}] worth > #{state.workspace} #{mode_label}  turn:#{state.turn}  $#{Float.round(state.cost, 3)}"

    text(header_text, Style.from(fg: :cyan, attrs: [:bold]))
  end

  defp render_chat(state) do
    all_nodes =
      state.messages
      |> Enum.flat_map(&message_to_nodes/1)
      |> then(fn nodes ->
        if state.streaming_text != "" and state.status == :running do
          nodes ++ message_to_nodes({:assistant, state.streaming_text})
        else
          nodes
        end
      end)

    if all_nodes == [] do
      [text("Welcome to worth. Type a message or /help for commands.", Style.from(fg: :bright_black))]
    else
      all_nodes
    end
  end

  defp render_input(state) do
    text("> #{state.input_text}", Style.from(fg: :green))
  end

  defp render_sidebar(state, width) do
    tabs_label =
      case state.sidebar_tab do
        :workspace -> "Workspace"
        :tools -> "Tools"
        :status -> "Status"
      end

    content =
      case state.sidebar_tab do
        :workspace ->
          ws_list = Worth.Workspace.Service.list()

          ws_lines =
            if ws_list == [],
              do: ["  (none)"],
              else:
                Enum.map(ws_list, fn ws ->
                  if ws == state.workspace, do: "  * #{ws}", else: "    #{ws}"
                end)

          [text("Workspaces:", Style.from(attrs: [:bold])) | Enum.map(ws_lines, &text/1)]

        :tools ->
          tools =
            ~w(read_file write_file edit_file bash list_files skill_list skill_read memory_query search_tools use_tool)

          [
            text("Active Tools:", Style.from(attrs: [:bold]))
            | Enum.map(tools, fn t -> text("  #{t}", Style.from(fg: :bright_black)) end)
          ]

        :status ->
          [
            text("Status:", Style.from(attrs: [:bold])),
            text("  Mode: #{state.mode}"),
            text("  Cost: $#{Float.round(state.cost, 3)}"),
            text("  Turns: #{state.turn}"),
            text("  Model: #{state.model}", Style.from(fg: :bright_black))
          ]
      end

    box(
      [text("[Tab: #{tabs_label}] (Tab to toggle)", Style.from(fg: :yellow)) | content],
      style: Style.new(),
      width: width
    )
  end

  defp message_to_nodes({:user, text}) do
    text
    |> String.split("\n")
    |> Enum.map(fn line -> text("> #{line}", Style.from(fg: :green)) end)
  end

  defp message_to_nodes({:assistant, text}) do
    text
    |> String.split("\n")
    |> Enum.map(fn line -> text(line) end)
  end

  defp message_to_nodes({:system, text}) do
    text
    |> String.split("\n")
    |> Enum.map(fn line -> text("[system] #{line}", Style.from(fg: :yellow)) end)
  end

  defp message_to_nodes({:error, text}) do
    text
    |> String.split("\n")
    |> Enum.map(fn line -> text("[error] #{line}", Style.from(fg: :red)) end)
  end

  defp message_to_nodes({:tool_call, %{name: name, input: input}}) do
    input_preview =
      input
      |> (fn i -> if is_map(i), do: Jason.encode!(i, pretty: false), else: inspect(i) end).()
      |> String.slice(0, 80)

    [
      text("", nil),
      text("  >> #{name}(#{input_preview})", Style.from(fg: :blue, attrs: [:dim]))
    ]
  end

  defp message_to_nodes({:tool_result, %{name: name, output: output}}) do
    preview = String.slice(output || "", 0, 100)

    [
      text("  << #{name}: #{preview}", Style.from(fg: :magenta, attrs: [:dim]))
    ]
  end

  defp message_to_nodes({:thinking, text}) do
    [
      text("  (thinking: #{String.slice(text, 0, 60)}...)", Style.from(fg: :bright_black, attrs: [:dim]))
    ]
  end

  defp drain_events(state) do
    receive do
      {:agent_event, {:text_chunk, chunk}} ->
        drain_events(%{state | streaming_text: state.streaming_text <> chunk})

      {:agent_event, {:status, status}} ->
        drain_events(%{state | status: status})

      {:agent_event, {:cost, amount}} ->
        drain_events(%{state | cost: state.cost + amount})

      {:agent_event, {:tool_call, %{name: name, input: input}}} ->
        messages = state.messages ++ [{:tool_call, %{name: name, input: input}}]
        drain_events(%{state | messages: messages})

      {:agent_event, {:tool_result, %{name: name, output: output}}} ->
        messages = state.messages ++ [{:tool_result, %{name: name, output: output}}]
        drain_events(%{state | messages: messages})

      {:agent_event, {:thinking_chunk, text}} ->
        messages = state.messages ++ [{:thinking, text}]
        drain_events(%{state | messages: messages})

      {:agent_event, {:done, %{text: text}}} ->
        final = if state.streaming_text != "", do: state.streaming_text, else: text || ""
        messages = state.messages ++ [{:assistant, final}]
        %{state | messages: messages, streaming_text: "", status: :idle}

      {:agent_event, {:error, reason}} ->
        messages = state.messages ++ [{:error, "Error: #{reason}"}]
        %{state | messages: messages, status: :idle, streaming_text: ""}

      {:agent_event, _} ->
        drain_events(state)
    after
      0 -> state
    end
  end

  defp parse_command(text) do
    case String.split(text, " ", parts: 2) do
      ["/quit"] ->
        {:command, :quit}

      ["/clear"] ->
        {:command, :clear}

      ["/cost"] ->
        {:command, :cost}

      ["/help"] ->
        {:command, :help}

      ["/status"] ->
        {:command, {:status, nil}}

      ["/mode", mode] ->
        case mode do
          m when m in ["code", "research", "planned", "turn_by_turn"] ->
            {:command, {:mode, String.to_atom(m)}}

          _ ->
            {:command, {:unknown, "/mode #{mode}"}}
        end

      ["/workspace", "list"] ->
        {:command, {:workspace, :list}}

      ["/workspace", "switch", name] ->
        {:command, {:workspace, {:switch, name}}}

      ["/workspace", "new", name] ->
        {:command, {:workspace, {:new, name}}}

      ["/" <> _ = cmd | _] ->
        {:command, {:unknown, cmd}}

      _ ->
        :message
    end
  end

  defp help_text do
    """
    Commands:
      /help              Show this help
      /quit              Exit worth
      /clear             Clear chat history
      /cost              Show session cost and turn count
      /status            Show current status
      /mode <mode>       Switch mode: code | research | planned | turn_by_turn
      /workspace list    List workspaces
      /workspace new <n> Create workspace
      /workspace switch  Switch workspace
      Tab                Toggle sidebar
      Up/Down            Command history
    """
  end

  defp send_message_to_brain(text) do
    ui_pid = self()

    Task.Supervisor.start_child(Worth.TaskSupervisor, fn ->
      case Worth.Brain.send_message(text) do
        {:ok, response} ->
          send(ui_pid, {:agent_event, {:done, response}})

        {:error, reason} ->
          send(ui_pid, {:agent_event, {:error, reason}})
      end
    end)
  end
end
