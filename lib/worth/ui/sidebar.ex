defmodule Worth.UI.Sidebar do
  @moduledoc """
  Right-hand sidebar with tab indicator and per-tab content.

  Tabs: `:workspace`, `:tools`, `:skills`, `:status`, `:usage`, `:logs`.
  The active tab is driven by `state.selected_tab`; rendering is
  otherwise stateless.
  """

  import TermUI.Component.Helpers
  alias TermUI.Renderer.Style

  @tabs [:workspace, :tools, :skills, :status, :usage, :logs]
  @log_tail 50

  def render(state, _opts \\ []) do
    active = Map.get(state, :selected_tab, :status)

    tab_header = text(" #{tab_dots(active)}", Style.new(fg: :cyan))
    divider = horizontal_rule()

    content = tab_content(state, active)

    stack(:vertical, [tab_header, divider | content])
  end

  def vertical_divider(height) do
    lines = for _ <- 1..height, do: "│"
    text(Enum.join(lines, "\n"), Style.new(fg: :bright_black))
  end

  def horizontal_rule do
    text(String.duplicate("─", 60), Style.new(fg: :bright_black))
  end

  defp tab_dots(active) do
    Enum.map_join(@tabs, " ", fn t -> if t == active, do: "●", else: "○" end)
  end

  defp tab_content(state, :workspace), do: workspace_tab(state)
  defp tab_content(state, :tools), do: tools_tab(state)
  defp tab_content(state, :skills), do: skills_tab(state)
  defp tab_content(state, :status), do: status_tab(state)
  defp tab_content(state, :usage), do: usage_tab(state)
  defp tab_content(state, :logs), do: logs_tab(state)

  def workspace_tab(_state) do
    ws_list = Worth.Workspace.Service.list()
    lines = if ws_list == [], do: ["  (none)"], else: Enum.map(ws_list, &"  #{&1}")
    [text("Workspace", Style.new(attrs: [:bold])) | Enum.map(lines, &text(&1))]
  end

  def tools_tab(_state) do
    tools = ~w(read_file write_file edit_file bash list_files memory_query skill_list)

    [
      text("Tools", Style.new(attrs: [:bold]))
      | Enum.map(tools, &text("  #{&1}", Style.new(fg: :bright_black)))
    ]
  end

  def skills_tab(_state) do
    skills = Worth.Skill.Registry.all()

    if skills == [] do
      [
        text("Skills", Style.new(attrs: [:bold])),
        text("  (none)", Style.new(fg: :bright_black))
      ]
    else
      lines = Enum.map(skills, fn s -> "  #{s.name} [#{s.trust_level}]" end)
      [text("Skills", Style.new(attrs: [:bold])) | Enum.map(lines, &text(&1))]
    end
  end

  def status_tab(state) do
    primary = Map.get(state.models, :primary, %{})
    lightweight = Map.get(state.models, :lightweight, %{})

    catalog_info = AgentEx.LLM.Catalog.info()

    model_lines = [
      text("Status", Style.new(attrs: [:bold])),
      text("  Mode:  #{state.mode}"),
      text("  Cost:  $#{Float.round(state.cost, 4)}"),
      text("  Turns: #{state.turn}"),
      text("  Models (#{catalog_info.model_count} in catalog)", Style.new(attrs: [:bold])),
      text("    primary:     #{model_line(primary)}", Style.new(fg: :bright_black)),
      text("      via #{source_line(primary)} #{model_meta(primary)}", Style.new(fg: :bright_black)),
      text("    lightweight: #{model_line(lightweight)}", Style.new(fg: :bright_black)),
      text(
        "      via #{source_line(lightweight)} #{model_meta(lightweight)}",
        Style.new(fg: :bright_black)
      )
    ]

    provider_lines =
      catalog_info.providers
      |> Enum.map(fn {id, stat} ->
        label = id |> Atom.to_string() |> String.capitalize()

        detail =
          case stat.status do
            :ok -> "#{stat.count} models"
            :static -> "#{stat.count} (static)"
            :fallback -> "#{stat.count} (fallback)"
            :no_creds -> "no key"
          end

        text("    #{label}: #{detail}", Style.new(fg: :bright_black))
      end)

    if provider_lines == [] do
      model_lines
    else
      model_lines ++ [text("  Providers", Style.new(attrs: [:bold])) | provider_lines]
    end
  end

  def usage_tab(_state) do
    metrics = Worth.Metrics.session()
    snapshots = AgentEx.LLM.UsageManager.snapshot()

    provider_lines =
      if snapshots == [] do
        [text("  (no providers expose quota)", Style.new(fg: :bright_black))]
      else
        Enum.flat_map(snapshots, &usage_snapshot_lines/1)
      end

    session_lines =
      [
        text("Session", Style.new(attrs: [:bold])),
        text("  Cost:    $#{Float.round(metrics.cost, 4)} (#{metrics.calls} calls)"),
        text("  Tokens:  #{format_int(metrics.input_tokens)} in / #{format_int(metrics.output_tokens)} out"),
        text(
          "  Cache:   #{format_int(metrics.cache_read)} read / #{format_int(metrics.cache_write)} write",
          Style.new(fg: :bright_black)
        ),
        text("  Embed:   #{metrics.embed_calls} calls", Style.new(fg: :bright_black))
      ]

    by_provider_lines =
      case Map.to_list(metrics.by_provider) do
        [] ->
          []

        entries ->
          [text("  By provider", Style.new(attrs: [:bold]))] ++
            Enum.map(entries, fn {provider, p} ->
              label = format_provider(provider)

              text(
                "    #{label}  $#{Float.round(p.cost, 4)} (#{p.calls})",
                Style.new(fg: :bright_black)
              )
            end)
      end

    [
      text("Usage", Style.new(attrs: [:bold])),
      text("Providers", Style.new(attrs: [:bold]))
    ] ++ provider_lines ++ session_lines ++ by_provider_lines
  end

  defp usage_snapshot_lines(%AgentEx.LLM.Usage{label: label, credits: credits, windows: windows}) do
    header =
      text("  #{label}", Style.new(fg: :white))

    credit_line =
      case credits do
        %{used: used, limit: limit} ->
          [text("    credits: $#{Float.round(used, 2)} / $#{Float.round(limit, 2)}", Style.new(fg: :bright_black))]

        _ ->
          []
      end

    window_lines =
      Enum.map(windows, fn w ->
        text("    #{w.label}: #{format_window(w)}", Style.new(fg: :bright_black))
      end)

    [header] ++ credit_line ++ window_lines
  end

  defp format_window(%AgentEx.LLM.UsageWindow{used: used, limit: limit, unit: unit})
       when is_number(limit) do
    used_str = if is_number(used), do: "#{used}", else: "?"
    "#{used_str}/#{limit} #{unit}"
  end

  defp format_window(_), do: "?"

  defp format_provider(name) when is_atom(name), do: Atom.to_string(name)
  defp format_provider(name) when is_binary(name), do: name
  defp format_provider(other), do: inspect(other)

  defp format_int(n) when is_integer(n) and n >= 1000 do
    n
    |> Integer.to_string()
    |> String.reverse()
    |> String.replace(~r/(\d{3})(?=\d)/, "\\1,")
    |> String.reverse()
  end

  defp format_int(n) when is_integer(n), do: Integer.to_string(n)
  defp format_int(_), do: "0"

  defp model_meta(%{context_window: ctx}) when is_integer(ctx) and ctx > 0 do
    ctx_k = div(ctx, 1000)
    "(#{ctx_k}k ctx)"
  end

  defp model_meta(_), do: ""

  defp model_line(%{label: label}) when is_binary(label) and label != "", do: label
  defp model_line(_), do: "(detecting…)"

  defp source_line(%{source: source}) when is_binary(source) and source != "", do: source
  defp source_line(_), do: "no route yet"

  def logs_tab(_state) do
    entries = Worth.UI.LogBuffer.recent(@log_tail)

    body =
      if entries == [] do
        [text("  (no log entries)", Style.new(fg: :bright_black))]
      else
        Enum.map(entries, &log_line/1)
      end

    [text("Logs", Style.new(attrs: [:bold])) | body]
  end

  defp log_line(%{level: level, text: line}) do
    text("  [#{short_level(level)}] #{truncate(line)}", Style.new(fg: log_color(level)))
  end

  defp short_level(:emergency), do: "emrg"
  defp short_level(:alert), do: "alrt"
  defp short_level(:critical), do: "crit"
  defp short_level(:error), do: "err "
  defp short_level(:warning), do: "warn"
  defp short_level(:notice), do: "note"
  defp short_level(:info), do: "info"
  defp short_level(:debug), do: "dbg "
  defp short_level(other), do: to_string(other)

  defp log_color(level) when level in [:emergency, :alert, :critical, :error], do: :red
  defp log_color(:warning), do: :yellow
  defp log_color(:notice), do: :cyan
  defp log_color(:info), do: :white
  defp log_color(:debug), do: :bright_black
  defp log_color(_), do: :white

  defp truncate(line) do
    line
    |> String.replace("\n", " ")
    |> String.slice(0, 200)
  end
end
