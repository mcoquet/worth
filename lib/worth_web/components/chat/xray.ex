defmodule WorthWeb.Components.Chat.XRay do
  @moduledoc """
  X-Ray debug panel component showing internal system events.
  Toggle via the header button or `/xray` command.
  """
  use Phoenix.Component

  import WorthWeb.CoreComponents, only: [icon: 1]
  import WorthWeb.ThemeHelper, only: [color: 1]

  attr :events, :list, required: true
  attr :visible, :boolean, required: true

  def xray_panel(assigns) do
    ~H"""
    <div
      :if={@visible}
      class={"flex flex-col h-64 shrink-0 border-t #{color(:border)} #{color(:surface)}"}
    >
      <div class={"flex items-center gap-2 px-3 py-1.5 text-xs font-bold #{color(:surface_elevated)} border-b #{color(:border)}"}>
        <.icon name="hero-eye" class="size-3 color(:accent)" />
        <span class="color(:accent)">X-RAY</span>
        <span class="color(:text_dim)">({length(@events)} events)</span>
        <div class="flex-1" />
        <button
          phx-click="clear_xray"
          class={"px-2 py-0.5 rounded text-xs transition-colors #{color(:button_secondary)} cursor-pointer"}
        >
          clear
        </button>
      </div>

      <div class="flex-1 overflow-y-auto p-2 space-y-1 text-xs font-mono">
        <div :if={@events == []} class="color(:text_dim) italic p-2">
          Waiting for events...
        </div>
        <div :for={{idx, event} <- Enum.with_index(Enum.reverse(@events))}>
          <.xray_event event={event} index={idx} />
        </div>
      </div>
    </div>
    """
  end

  defp xray_event(assigns) do
    ~H"""
    <div class={"px-2 py-1 rounded #{color(:surface_elevated)} border-l-2 #{event_border_color(@event)}"}>
      <div class="flex items-center gap-1.5">
        <span class="color(:text_dim) shrink-0">{event_time(@event)}</span>
        <span class={event_type_class(@event)}>{event_type_label(@event)}</span>
        <span class="color(:text) truncate flex-1">{event_summary(@event)}</span>
      </div>
      <div :if={event_detail(@event)} class="mt-1 ml-4 color(:text_muted) whitespace-pre-wrap max-h-32 overflow-y-auto">
        <pre class="text-xs">{event_detail(@event)}</pre>
      </div>
    </div>
    """
  end

  defp event_border_color({:model_selection, _}), do: "border-ctp-blue"
  defp event_border_color({:tool_call, _}), do: "border-ctp-yellow"
  defp event_border_color({:tool_result, _}), do: "border-ctp-green"
  defp event_border_color({:memory_search, _}), do: "border-ctp-mauve"
  defp event_border_color({:memory_write, _}), do: "border-ctp-pink"
  defp event_border_color({:mcp, _}), do: "border-ctp-teal"
  defp event_border_color(_), do: "border-ctp-overlay0"

  defp event_type_label({:model_selection, _}), do: "MODEL"
  defp event_type_label({:tool_call, _}), do: "TOOL>"
  defp event_type_label({:tool_result, _}), do: "TOOL<"
  defp event_type_label({:memory_search, _}), do: "MEM>"
  defp event_type_label({:memory_write, _}), do: "MEM<"
  defp event_type_label({:mcp, _}), do: "MCP"
  defp event_type_label(_), do: "???"

  defp event_type_class({:model_selection, _}), do: "color(:info) font-bold"
  defp event_type_class({:tool_call, _}), do: "color(:warning) font-semibold"
  defp event_type_class({:tool_result, %{status: :failed}}), do: "color(:error) font-semibold"
  defp event_type_class({:tool_result, _}), do: "color(:success) font-semibold"
  defp event_type_class({:memory_search, _}), do: "color(:secondary) font-semibold"
  defp event_type_class({:memory_write, _}), do: "color(:primary) font-semibold"
  defp event_type_class({:mcp, _}), do: "color(:info) font-semibold"
  defp event_type_class(_), do: "color(:text_dim)"

  defp event_summary({:model_selection, info}) do
    pref = Map.get(info, :preference, "?")
    filter = Map.get(info, :filter, "none")
    complexity = Map.get(info, :complexity, "?")
    selected = get_in(info, [:selected, :model_id]) || "?"

    "selected=#{selected} complexity=#{complexity} pref=#{pref} filter=#{filter}"
  end

  defp event_summary({:tool_call, %{name: name}}), do: "calling #{name}"
  defp event_summary({:tool_result, %{name: name, status: status}}), do: "#{name} → #{status}"

  defp event_summary({:memory_search, %{query: query, result_count: count}}),
    do: "query=\"#{truncate_str(query, 60)}\" → #{count} results"

  defp event_summary({:memory_write, %{type: type, content: content}}),
    do: "write #{type}: \"#{truncate_str(content, 60)}\""

  defp event_summary({:mcp, {:mcp_failed, name}}), do: "#{name} failed"
  defp event_summary({:mcp, {:mcp_reconnected, name}}), do: "#{name} reconnected"
  defp event_summary({:mcp, {:mcp_reconnect_failed, name}}), do: "#{name} reconnect failed"
  defp event_summary(_), do: ""

  defp event_detail({:model_selection, info}) do
    candidates = Map.get(info, :candidates, [])
    explanation = Map.get(info, :explanation, "")

    needs = []
    needs = if info[:needs_vision], do: ["vision" | needs], else: needs
    needs = if info[:needs_audio], do: ["audio" | needs], else: needs
    needs = if info[:needs_reasoning], do: ["reasoning" | needs], else: needs
    needs = if info[:needs_large_context], do: ["large_context" | needs], else: needs

    parts = []

    parts =
      if explanation == "" do
        parts
      else
        ["Analysis: #{explanation}" | parts]
      end

    parts =
      if needs == [] do
        parts
      else
        ["Needs: #{Enum.join(needs, ", ")}" | parts]
      end

    parts =
      if candidates == [] do
        parts
      else
        candidate_lines =
          Enum.map_join(candidates, "\n", fn c ->
            free_tag = if c[:free], do: " [FREE]", else: ""
            "  #{c[:score]}  #{c[:provider]}/#{c[:model_id]}#{free_tag}"
          end)

        ["Ranked candidates:\n#{candidate_lines}" | parts]
      end

    case Enum.reverse(parts) do
      [] -> nil
      lines -> Enum.join(lines, "\n")
    end
  end

  defp event_detail({:tool_call, %{input: input}}) when input != nil and input != %{} do
    "Input: #{format_input(input)}"
  end

  defp event_detail({:tool_result, %{output: output}}) when is_binary(output) and byte_size(output) > 0 do
    truncated = if String.length(output) > 500, do: String.slice(output, 0, 500) <> "\n... (truncated)", else: output
    "Output: #{truncated}"
  end

  defp event_detail({:tool_result, %{output: output}}) when output != nil do
    "Output: #{inspect(output, limit: 500)}"
  end

  defp event_detail(_), do: nil

  defp event_time(%{timestamp: ts}) when is_integer(ts) do
    ts
    |> DateTime.from_unix!(:millisecond)
    |> Calendar.strftime("%H:%M:%S")
  end

  defp event_time(_), do: "??"

  defp format_input(input) when is_map(input) do
    inspected = inspect(input, limit: 300)

    if String.length(inspected) > 500 do
      String.slice(inspected, 0, 500) <> "..."
    else
      inspected
    end
  end

  defp format_input(input), do: inspect(input, limit: 300)

  defp truncate_str(str, max) when is_binary(str) do
    if String.length(str) > max, do: String.slice(str, 0, max) <> "...", else: str
  end

  defp truncate_str(_, _), do: ""
end
